//
//  G1Controller.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 26/1/25.
//

import Foundation
import Combine
import CoreObjC
import CoreLocation
import CoreBluetooth

public final class G1Controller: NSObject {
    public static let shared = G1Controller()
    private var cancellables = Set<AnyCancellable>()
    private var sequenceNumber: UInt16 = 0

    private let speechRecognizer: SpeechStreamRecognizer
    private let bluetoothManager: G1BluetoothManager
    private var openAIAPIKey: String?
    private var openAIBaseURL: String = "https://api.openai.com/v1/chat/completions"
    private var openAIModel: String = "gpt-3.5-turbo"
    
    private var weatherTimer: Timer?
    private var locationManager: CLLocationManager?
    private var useFahrenheit: Bool = false
    private var use24Hour: Bool = true
    private var currentWeatherCode: UInt8 = 0 {
        didSet {
            G1SettingsManager.shared.lastWeatherCode = Int(currentWeatherCode)
        }
    }
    private var currentTempCelsius: Double = 0 {
        didSet {
            G1SettingsManager.shared.lastTemperatureCelsius = currentTempCelsius
        }
    }
    private var hasWeatherData: Bool = false {
        didSet {
            G1SettingsManager.shared.hasWeatherData = hasWeatherData
            G1SettingsManager.shared.lastWeatherUpdateTime = Date().timeIntervalSince1970
        }
    }
    
    // Update access level to internal to match G1BluetoothManager
    internal var rightPeripheral: CBPeripheral? {
        return bluetoothManager.rightPeripheral
    }
    
    internal var leftPeripheral: CBPeripheral? {
        return bluetoothManager.leftPeripheral
    }
    
    internal func findCharacteristic(uuid: CBUUID, peripheral: CBPeripheral) -> CBCharacteristic? {
        return bluetoothManager.findCharacteristic(uuid: uuid, peripheral: peripheral)
    }
    
    internal var UART_TX_CHAR_UUID: CBUUID {
        return bluetoothManager.UART_TX_CHAR_UUID
    }
    
    private var displayTemperature: Int {
        if useFahrenheit {
            print("Converting temperature - Raw Celsius value: \(currentTempCelsius)")
            let fahrenheit = (currentTempCelsius * 9.0/5.0) + 32.0
            print("Calculated Fahrenheit value: \(fahrenheit)")
            let rounded = Int(round(fahrenheit))
            print("Rounded Fahrenheit value: \(rounded)")
            return rounded
        } else {
            return Int(round(currentTempCelsius))
        }
    }
    
    public var g1Manager: G1BluetoothManager {
        return bluetoothManager
    }

    @Published public var g1Connected: Bool = false
    @Published public var isProcessingAI: Bool = false
    @Published public var isContinuousListening: Bool = false
    
    public var previewTextPublisher: AnyPublisher<String, Never> {
        speechRecognizer.$previewText.eraseToAnyPublisher()
    }
    
    // Add WeatherData model and publisher
    public struct WeatherData {
        let temperature: Double
        let condition: String
        let useFahrenheit: Bool
    }
    
    private let weatherSubject = PassthroughSubject<WeatherData?, Never>()
    public var weatherPublisher: AnyPublisher<WeatherData?, Never> {
        weatherSubject.eraseToAnyPublisher()
    }
    
    private var pendingBatteryUpdate: Bool = false
    
    public var is24HourFormat: Bool {
        return use24Hour
    }
    
    private override init() {
        self.speechRecognizer = SpeechStreamRecognizer()
        self.bluetoothManager = G1BluetoothManager()
        
        // Load persisted values
        if G1SettingsManager.shared.hasWeatherData {
            self.hasWeatherData = true
            self.currentTempCelsius = G1SettingsManager.shared.lastTemperatureCelsius
            self.currentWeatherCode = UInt8(G1SettingsManager.shared.lastWeatherCode)
        }
        
        // Load other settings
        self.useFahrenheit = G1SettingsManager.shared.useFahrenheit
        self.use24Hour = G1SettingsManager.shared.use24Hour
        
        super.init()
        handleRecogizerReady()
        handleReady()
        handleBatteryUpdates()
    }

    public func configureOpenAI(apiKey: String, baseURL: String? = nil, model: String? = nil) {
        self.openAIAPIKey = apiKey
        G1SettingsManager.shared.apiKey = apiKey
        
        if let baseURL = baseURL {
            self.openAIBaseURL = baseURL
            G1SettingsManager.shared.apiEndpoint = baseURL
        }
        
        if let model = model {
            self.openAIModel = model
            G1SettingsManager.shared.selectedModel = model
        }
    }

    public func configureWeather() {
        // Create location manager if not exists
        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer
            locationManager?.allowsBackgroundLocationUpdates = true
            locationManager?.pausesLocationUpdatesAutomatically = false
            locationManager?.showsBackgroundLocationIndicator = true
        }
        
        // Check current authorization status
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location already authorized, starting location updates")
            startLocationUpdates()
            G1SettingsManager.shared.weatherEnabled = true
            
            // Force an immediate weather update
            if let location = locationManager?.location {
                print("Location available, fetching weather immediately")
                fetchWeatherData(for: location)
            }
            
        case .notDetermined:
            print("Requesting location authorization")
            locationManager?.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("Location access denied or restricted. Weather updates will not be available.")
            hasWeatherData = false
            G1SettingsManager.shared.weatherEnabled = false
            updateDashboardTime()
        @unknown default:
            print("Unknown location authorization status")
        }
    }

    private func startLocationUpdates() {
        locationManager?.startUpdatingLocation()
        locationManager?.startMonitoringSignificantLocationChanges()
        
        // Check if we need to update weather (if last update was more than 15 minutes ago)
        if let lastUpdateTime = G1SettingsManager.shared.lastWeatherUpdateTime {
            let timeSinceLastUpdate = Date().timeIntervalSince1970 - lastUpdateTime
            if timeSinceLastUpdate >= 900 { // 15 minutes
                if let location = locationManager?.location {
                    print("Last weather update was \(Int(timeSinceLastUpdate))s ago, updating...")
                    fetchWeatherData(for: location)
                }
            } else {
                print("Last weather update was \(Int(timeSinceLastUpdate))s ago, using cached data")
                // Use cached weather data
                if G1SettingsManager.shared.hasWeatherData {
                    hasWeatherData = true
                    currentTempCelsius = G1SettingsManager.shared.lastTemperatureCelsius
                    currentWeatherCode = UInt8(G1SettingsManager.shared.lastWeatherCode)
                    updateDashboardTime()
                }
            }
        } else {
            // No previous update time found, update immediately if location available
            if let location = locationManager?.location {
                print("No previous weather data, fetching immediately")
                fetchWeatherData(for: location)
            }
        }
    }

    private func fetchWeatherData(for location: CLLocation) {
        print("Fetching weather for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current=temperature_2m,weather_code&timezone=\(TimeZone.current.identifier)"
        
        guard let url = URL(string: urlString) else {
            print("Failed to create weather URL")
            return
        }
        
        print("Fetching weather from URL: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Weather fetch error: \(error.localizedDescription)")
                self?.hasWeatherData = false
                DispatchQueue.main.async {
                    self?.updateDashboardTime()
                    self?.weatherSubject.send(nil)
                }
                return
            }
            
            guard let data = data else {
                print("No weather data received")
                self?.hasWeatherData = false
                DispatchQueue.main.async {
                    self?.updateDashboardTime()
                    self?.weatherSubject.send(nil)
                }
                return
            }
            
            // Print raw response for debugging
            if let responseStr = String(data: data, encoding: .utf8) {
                print("Weather API Response: \(responseStr)")
            }
            
            do {
                let weather = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                print("Successfully decoded weather data: temp=\(weather.current.temperature_2m)°C, code=\(weather.current.weather_code)")
                
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    // Store the raw Celsius temperature
                    self.currentTempCelsius = weather.current.temperature_2m
                    
                    // Store weather code
                    self.currentWeatherCode = self.mapWeatherCode(weather.current.weather_code)
                    print("Mapped weather code \(weather.current.weather_code) to \(String(format: "0x%02X", self.currentWeatherCode))")
                    
                    self.hasWeatherData = true
                    
                    // Save weather data to settings
                    G1SettingsManager.shared.lastTemperatureCelsius = weather.current.temperature_2m
                    G1SettingsManager.shared.lastWeatherCode = Int(self.currentWeatherCode)
                    G1SettingsManager.shared.lastWeatherUpdateTime = Date().timeIntervalSince1970
                    G1SettingsManager.shared.hasWeatherData = true
                    
                    // Send weather update
                    let condition = self.getWeatherCondition(weather.current.weather_code)
                    self.weatherSubject.send(WeatherData(
                        temperature: weather.current.temperature_2m,
                        condition: condition,
                        useFahrenheit: self.useFahrenheit
                    ))
                    
                    // Update dashboard with new weather data
                    self.updateDashboardTime()
                }
            } catch {
                print("Failed to decode weather data: \(error)")
                self?.hasWeatherData = false
                DispatchQueue.main.async {
                    self?.updateDashboardTime()
                    self?.weatherSubject.send(nil)
                }
            }
        }.resume()
    }

    public func disableWeather() {
        locationManager?.stopUpdatingLocation()
        locationManager?.stopMonitoringSignificantLocationChanges()
        hasWeatherData = false
        G1SettingsManager.shared.weatherEnabled = false
        updateDashboardTime()
    }

    public func setTimeFormat(use24Hour: Bool) {
        self.use24Hour = use24Hour
        G1SettingsManager.shared.use24Hour = use24Hour
        updateDashboardTime()
    }
    
    public func setTemperatureUnit(useFahrenheit: Bool) {
        self.useFahrenheit = useFahrenheit
        G1SettingsManager.shared.useFahrenheit = useFahrenheit
        if hasWeatherData {
            updateDashboardTime() // This also updates weather
        }
    }

    private func processWithOpenAI(text: String) {
        guard let apiKey = openAIAPIKey else {
            print("OpenAI API key not configured")
            return
        }
        
        isProcessingAI = true
        
        // Ensure we have a valid chat completions endpoint
        var urlString = openAIBaseURL.trimmingCharacters(in: .whitespaces)
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        if !urlString.hasSuffix("v1/chat/completions") {
            urlString += "v1/chat/completions"
        }
        
        guard let url = URL(string: urlString) else {
            isProcessingAI = false
            print("Invalid OpenAI URL: \(urlString)")
            Task {
                await sendTextToGlasses(text: "Error: Invalid API URL", status: .ERROR_TEXT)
            }
            return
        }
        
        let messages = [
            ["role": "user", "content": text]
        ]
        
        let requestBody: [String: Any] = [
            "model": openAIModel,
            "messages": messages,
            "temperature": 0.7
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            isProcessingAI = false
            print("Failed to serialize request body")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        print("Sending request to OpenAI URL: \(url.absoluteString)")
        print("Request body: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> OpenAIResponse in
                // Print the raw response for debugging
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("OpenAI Raw Response: \(responseStr)")
                }
                
                // Check for error response
                if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    throw OpenAIError.apiError(errorResponse.detail)
                }
                
                return try JSONDecoder().decode(OpenAIResponse.self, from: data)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isProcessingAI = false
                    if case .failure(let error) = completion {
                        let errorMessage: String
                        if let openAIError = error as? OpenAIError {
                            errorMessage = openAIError.localizedDescription
                        } else {
                            errorMessage = error.localizedDescription
                        }
                        print("OpenAI API Error: \(error)")
                        Task {
                            await self?.sendTextToGlasses(text: "Error: \(errorMessage)", status: .ERROR_TEXT)
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    guard let content = response.choices.first?.message.content else {
                        print("No content in OpenAI response")
                        return
                    }
                    Task {
                        await self?.sendTextToGlasses(text: content, status: .NORMAL_TEXT)
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func startSpeechRecognition() {
        speechRecognizer.startRecognition()
    }

    private func stopSpeechRecognition() {
        speechRecognizer.stopRecognition()
    }

    public func startBluetoothScanning() {
        bluetoothManager.startScan()
    }
    
    private func handleRecogizerReady() {
        speechRecognizer.$initiallized.sink { [weak self] initialized in
            guard let self = self else { return }
            if initialized {
                handleListenTrigger()
                handleIncomingVoiceData()
                handleRecognizedText()
                handlePreviewText()
                handleWakeWord()
            }
        }
        .store(in: &cancellables)
    }
    
    private func handleReady() {
        bluetoothManager.$g1Ready.sink { [weak self] ready in
            guard let self = self else { return }
            self.g1Connected = ready
        }
        .store(in: &cancellables)
    }
    
    private func handleListenTrigger() {
        bluetoothManager.$aiListening.sink { [weak self] listening in
            guard let self = self else { return }
            // Only respond to AI listening changes if we're not in continuous mode
            if !self.isContinuousListening {
                if listening {
                    self.startSpeechRecognition()
                } else {
                    self.stopSpeechRecognition()
                }
            }
        }
        .store(in: &cancellables)
    }
    
    private func handlePreviewText() {
        speechRecognizer.$previewText
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self, !text.isEmpty, text != "Listening..." else { return }
                Task {
                    // Build command with proper flags for direct text display
                    let displayText = "Listening...\n\n\(text)"
                    guard let textData = displayText.data(using: .utf8) else { return }
                    
                    var command: [UInt8] = [
                        0x4E,           // SEND_RESULT command
                        0x00,           // sequence number
                        0x01,           // total packages
                        0x00,           // current package
                        0x71,           // screen status (0x70 Text Show | 0x01 New Content)
                        0x00,           // char position 0
                        0x00,           // char position 1
                        0x01,           // page number
                        0x01            // max pages
                    ]
                    command.append(contentsOf: Array(textData))
                    
                    await self.g1Manager.sendCommand(command)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleIncomingVoiceData() {
        bluetoothManager.$voiceData.sink { [weak self] data in
            guard let self = self else { return }
            
            // Ensure we have enough data to process
            guard data.count > 2 else { 
                print("Received invalid PCM data size: \(data.count)")
                return 
            }
            
            // Skip the first 2 bytes which are command bytes
            let effectiveData = data.subdata(in: 2..<data.count)
            
            // Ensure we have valid PCM data
            guard effectiveData.count > 0 else {
                print("No PCM data after removing command bytes")
                return
            }
            
            let pcmConverter = PcmConverter()
            let pcmData = pcmConverter.decode(effectiveData)
            
            // Only log and process if we have valid PCM data
            if pcmData.count > 0 {
                print("Processing PCM data of size: \(pcmData.count)")
                self.speechRecognizer.appendPCMData(pcmData as Data)
            } else {
                print("PCM conversion resulted in empty data")
            }
        }
        .store(in: &cancellables)
    }
    
    private func handleRecognizedText() {
        speechRecognizer.$recognizedText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self, !text.isEmpty else { return }
                self.processWithOpenAI(text: text)
            }
            .store(in: &cancellables)
    }
    
    private func handleWakeWord() {
        speechRecognizer.$wakeWordDetected
            .dropFirst()
            .sink { [weak self] detected in
                guard let self = self, detected else { return }
                print("Wake word detected, starting transcription")
                Task {
                    // First stop wake word detection
                    self.speechRecognizer.stopWakeWordDetection()
                    // Then start normal transcription
                    self.startSpeechRecognition()
                }
            }
            .store(in: &cancellables)
    }
    
    public func sendTextToGlasses(text: String, status: DisplayStatus = .NORMAL_TEXT) async {
        await bluetoothManager.sendText(text: text, newScreen: true, currentPage: 1, maxPages: 1, isCommand: true, status: status)
    }

    private func getNextSequence() -> UInt16 {
        sequenceNumber = (sequenceNumber + 1) % UInt16.max
        return sequenceNumber
    }

    private func updateDashboardTime() {
        print("Updating dashboard - hasWeather: \(hasWeatherData), temp: \(displayTemperature), weatherCode: \(String(format: "0x%02X", currentWeatherCode))")
        
        Task {
            // First set dashboard mode to full with proper delay
            var modeCommand: [UInt8] = [
                0x06,                               // Command
                0x07,                              // Subcommand
                0x00,                              // Sequence
                0x08,                              // Mode value
                0x06,                              // API version
                0x00,                              // Mode (full)
                0x00                               // Reserved
            ]
            
            // Pad mode command to 20 bytes
            while modeCommand.count < 20 {
                modeCommand.append(0x00)
            }
            
            // Send mode command first with longer delay
            await bluetoothManager.sendCommand(modeCommand)
            try? await Task.sleep(nanoseconds: 500 * 1_000_000) // 500ms delay
            
            // Get current timestamp in local time
            let now = Date()
            let localTimestamp = now.timeIntervalSince1970 + TimeInterval(TimeZone.current.secondsFromGMT())
            let timestamp32 = UInt32(localTimestamp)
            let timestamp64 = UInt64(localTimestamp * 1000)
            
            // Then send weather data with timestamps
            var command: [UInt8] = [
                0x06,                               // Dashboard command
                0x15,                              // Subcommand
                0x00, 0x15,                        // Length (21 bytes)
                0x01,                              // API version
                // 32-bit timestamp (little endian)
                UInt8(timestamp32 & 0xFF),
                UInt8((timestamp32 >> 8) & 0xFF),
                UInt8((timestamp32 >> 16) & 0xFF),
                UInt8((timestamp32 >> 24) & 0xFF),
                // 64-bit timestamp (little endian)
                UInt8(timestamp64 & 0xFF),
                UInt8((timestamp64 >> 8) & 0xFF),
                UInt8((timestamp64 >> 16) & 0xFF),
                UInt8((timestamp64 >> 24) & 0xFF),
                UInt8((timestamp64 >> 32) & 0xFF),
                UInt8((timestamp64 >> 40) & 0xFF),
                UInt8((timestamp64 >> 48) & 0xFF),
                UInt8((timestamp64 >> 56) & 0xFF),
                hasWeatherData ? currentWeatherCode : 0x00,  // Weather icon
                UInt8(bitPattern: Int8(round(currentTempCelsius))),  // Temperature in Celsius as signed byte
                useFahrenheit ? 0x01 : 0x00,       // Temperature unit (0x01 = convert to F)
                use24Hour ? 0x00 : 0x01            // Time format
            ]
            
            // Pad command to 20 bytes
            while command.count < 20 {
                command.append(0x00)
            }
            
            print("Sending dashboard command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
            await bluetoothManager.sendCommand(command)
            try? await Task.sleep(nanoseconds: 500 * 1_000_000) // 500ms delay after sending
        }
    }
    
    private func getWeatherCondition(_ wmoCode: Int) -> String {
        switch wmoCode {
        case 0:
            return "clear"
        case 1, 2, 3:
            return "cloudy"
        case 45, 48:
            return "foggy"
        case 51, 53, 55, 56, 57:
            return "drizzle"
        case 61, 63, 65, 66, 67:
            return "rain"
        case 71, 73, 75, 77, 85, 86:
            return "snow"
        case 95, 96, 99:
            return "thunder"
        default:
            return "clear"
        }
    }
    
    private func mapWeatherCode(_ wmoCode: Int) -> UInt8 {
        switch wmoCode {
        case 0: // Clear sky
            return 0x10 // Sunny
        case 1, 2, 3: // Partly cloudy
            return 0x02 // Clouds
        case 45, 48: // Foggy
            return 0x0B // Fog
        case 51, 53, 55: // Drizzle
            return 0x03 // Drizzle
        case 56, 57: // Freezing drizzle
            return 0x0F // Freezing Rain
        case 61, 63: // Light/moderate rain
            return 0x05 // Rain
        case 65: // Heavy rain
            return 0x06 // Heavy Rain
        case 66, 67: // Freezing rain
            return 0x0F // Freezing Rain
        case 71, 73, 75, 77: // Snow
            return 0x09 // Snow
        case 80, 81, 82: // Rain showers
            return 0x05 // Rain
        case 85, 86: // Snow showers
            return 0x09 // Snow
        case 95: // Thunderstorm
            return 0x08 // Thunder Storm
        case 96, 99: // Thunderstorm with hail
            return 0x08 // Thunder Storm
        default:
            return 0x00 // None
        }
    }
    
    public func setDashboardMode(_ mode: DashboardMode, subMode: UInt8 = 0x00) async -> Bool {
        guard let rightGlass = rightPeripheral,
              let leftGlass = leftPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
              let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) else {
            return false
        }

        // Build dashboard mode command
        var command = Data()
        command.append(contentsOf: [0x06, 0x07]) // Command header
        command.append(contentsOf: [0x00, 0x00]) // Sequence
        command.append(0x06) // API
        command.append(mode.rawValue) // Main mode
        command.append(subMode) // Sub mode

        // Send command to both glasses with proper timing
        rightGlass.writeValue(command, for: rightTxChar, type: .withResponse)
        try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
        leftGlass.writeValue(command, for: leftTxChar, type: .withResponse)

        return true
    }

    private func fetchBatteryInfo() async {
        let command: [UInt8] = [0x2C, 0x01] // Battery info command
        await bluetoothManager.sendCommand(command)
    }

    private func handleBatteryUpdates() {
        // Check every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                print("Scheduled battery check - fetching fresh battery info")
                await self?.fetchBatteryInfo()
            }
        }
        
        // update when battery level changes
        bluetoothManager.$batteryLevel
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] newLevel in
                print("Battery level changed to: \(newLevel)%")
                self?.pendingBatteryUpdate = true
                // Only update immediately if we're in full mode
                if self?.bluetoothManager.currentDashboardMode == .full {
                    Task {
                        await self?.updateBatteryDisplay()
                    }
                }
            }
            .store(in: &cancellables)
            
        // Monitor dashboard mode changes
        bluetoothManager.$currentDashboardMode
            .sink { [weak self] mode in
                if mode == .full && self?.pendingBatteryUpdate == true {
                    Task {
                        await self?.updateBatteryDisplay()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateBatteryDisplay() async -> Bool {
        guard bluetoothManager.currentDashboardMode == .full else { 
            pendingBatteryUpdate = true
            return false 
        }
        
        // Get current battery level (using the lower of the two glasses)
        let batteryLevel = min(bluetoothManager.leftBatteryLevel, bluetoothManager.rightBatteryLevel)
        
        print("Updating battery display: \(batteryLevel)%")
        
        // Format battery information
        let batteryTitle = "Battery \(batteryLevel)%"
        let connectionStatus = "Connected to device"
        
        // Build calendar item command
        var bytes: [UInt8] = [
            0x00, // Fixed byte
            0x6d, // Fixed byte
            0x03, // Fixed byte
            0x01, // Fixed byte
            0x00, // Fixed byte
            0x01, // Fixed byte
            0x00, // Fixed byte
            0x00, // Fixed byte
            0x00, // Fixed byte
            0x03, // Fixed byte
            0x01  // Fixed byte
        ]
        
        // Add name (Battery Status)
        bytes.append(0x01) // name identifier
        bytes.append(UInt8(batteryTitle.utf8.count))
        bytes.append(contentsOf: Array(batteryTitle.utf8))
        
        // Add time (Connection Status)
        bytes.append(0x02) // time identifier
        bytes.append(UInt8(connectionStatus.utf8.count))
        bytes.append(contentsOf: Array(connectionStatus.utf8))
        
        // Add empty location to maintain format
        bytes.append(0x03) // location identifier
        bytes.append(0x00) // Empty string length
        
        // Calculate total length and add header
        let length = bytes.count + 2
        let command: [UInt8] = [0x06, UInt8(length)] + bytes
        
        // Send command to both glasses without changing mode
        guard let rightGlass = rightPeripheral,
              let leftGlass = leftPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
              let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) else {
            return false
        }
            
        let commandData = Data(command)
        rightGlass.writeValue(commandData, for: rightTxChar, type: .withResponse)
        try? await Task.sleep(nanoseconds: 50 * 1_000_000)
        leftGlass.writeValue(commandData, for: leftTxChar, type: .withResponse)
        
        pendingBatteryUpdate = false
        return true
    }

    public func writeToCalendarWidget(name: String, time: String, location: String) async -> Bool {
        guard let rightGlass = rightPeripheral,
              let leftGlass = leftPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
              let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) else {
            return false
        }
        
        // If we're not in full mode and there's a pending battery update, just queue it
        if bluetoothManager.currentDashboardMode != .full {
            pendingBatteryUpdate = true
            return true
        }
        
        // Update battery display and return its success status
        return await updateBatteryDisplay()
    }

    public func toggleContinuousListening() async -> Bool {
        guard let rightGlass = rightPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass) else {
            return false
        }
        
        isContinuousListening = !isContinuousListening
        G1SettingsManager.shared.continuousListeningEnabled = isContinuousListening
        
        if isContinuousListening {
            // Create a repeating task for wake word detection
            Task {
                while isContinuousListening {
                    // Send mic on command
                    var micOnData = Data()
                    micOnData.append(Commands.BLE_REQ_MIC_ON.rawValue)
                    micOnData.append(0x01)
                    rightGlass.writeValue(micOnData, for: rightTxChar, type: .withResponse)
                    print("Starting wake word detection cycle")
                    
                    // Start wake word detection
                    speechRecognizer.startWakeWordDetection()
                    
                    // Wait for 30 seconds
                    try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                    
                    // Turn off mic if still in continuous mode
                    if isContinuousListening {
                        var micOffData = Data()
                        micOffData.append(Commands.BLE_REQ_MIC_ON.rawValue)
                        micOffData.append(0x00)
                        rightGlass.writeValue(micOffData, for: rightTxChar, type: .withResponse)
                        print("Ending wake word detection cycle")
                        
                        // Stop wake word detection
                        speechRecognizer.stopWakeWordDetection()
                        
                        // Small delay before next cycle
                        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
                    }
                }
            }
        } else {
            // Just turn off the mic without any additional actions
            var micOffData = Data()
            micOffData.append(Commands.BLE_REQ_MIC_ON.rawValue)
            micOffData.append(0x00)
            rightGlass.writeValue(micOffData, for: rightTxChar, type: .withResponse)
            print("Turning microphone off")
            
            // Stop any ongoing recognition without triggering AI
            speechRecognizer.stopWakeWordDetection()
            
            // Reset any ongoing states
            bluetoothManager.aiMode = .AI_IDLE
        }
        
        return true
    }

    public func setDashboardPosition(_ position: DashboardPosition) async -> Bool {
        return await g1Manager.setDashboardPosition(position)
    }

    public func hideDashboard() async -> Bool {
        return await g1Manager.hideDashboard()
    }

    public func setDashboardDistance(_ distance: UInt8) async -> Bool {
        return await g1Manager.setDashboardDistance(distance)
    }

    public func setTiltAngle(_ degrees: UInt8) async -> Bool {
        return await g1Manager.setTiltAngle(degrees)
    }
}

// MARK: - OpenAI Response Models
struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct OpenAIErrorResponse: Codable {
    let detail: String
}

enum OpenAIError: LocalizedError {
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension G1Controller: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location access granted, starting weather updates")
            startLocationUpdates()
            // Force an immediate update if we have a location
            if let location = manager.location {
                print("Location immediately available after authorization, fetching weather")
                fetchWeatherData(for: location)
            }
        case .denied, .restricted:
            print("Location access denied or restricted. Weather updates will not be available.")
            hasWeatherData = false
            G1SettingsManager.shared.weatherEnabled = false
            updateDashboardTime()
        case .notDetermined:
            print("Location permission not determined yet")
        @unknown default:
            print("Unknown location authorization status")
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        // Update UI to show weather is unavailable
        hasWeatherData = false
        updateDashboardTime()
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("No valid location in update")
            return
        }
        
        // Only update if we don't have weather data or if it's been more than 15 minutes
        if !hasWeatherData || G1SettingsManager.shared.lastWeatherUpdateTime == nil {
            print("No weather data, fetching with new location")
            fetchWeatherData(for: location)
        } else if let lastUpdate = G1SettingsManager.shared.lastWeatherUpdateTime {
            let timeSinceLastUpdate = Date().timeIntervalSince1970 - lastUpdate
            if timeSinceLastUpdate >= 900 { // 15 minutes
                print("Weather data is \(Int(timeSinceLastUpdate))s old, updating with new location")
                fetchWeatherData(for: location)
            } else {
                print("Weather data is only \(Int(timeSinceLastUpdate))s old, skipping update")
            }
        }
    }
}

// MARK: - Weather Response Models
struct OpenMeteoResponse: Codable {
    let current: CurrentWeather
    
    struct CurrentWeather: Codable {
        let temperature_2m: Double
        let weather_code: Int
    }
}
