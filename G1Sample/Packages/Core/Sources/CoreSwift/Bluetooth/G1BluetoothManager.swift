//
//  G1BluetoothManager.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

import CoreBluetooth
import Foundation
import UIKit
import Combine

public struct QuickNote: Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    
    public static func == (lhs: QuickNote, rhs: QuickNote) -> Bool {
        return lhs.id == rhs.id
    }
}

public final class G1BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @Published public var g1Ready: Bool = false {
        didSet {
            if !g1Ready {
                // Reset battery levels when disconnected
                batteryLevel = 0
                leftBatteryLevel = 0
                rightBatteryLevel = 0
            }
        }
    }
    @Published public var voiceData: Data = Data()
    @Published private(set) var voiceState: VoiceState = .idle
    @Published private(set) var aiState: AiState = .idle
    @Published public var aiListening: Bool = false {
        didSet {
            // Keep aiListening in sync with voice state for backward compatibility
            if aiListening && voiceState == .idle {
                voiceState = .listening
            } else if !aiListening && voiceState == .listening {
                voiceState = .idle
            }
        }
    }
    @Published public private(set) var quickNotes: [QuickNote] = [] {
        didSet {
            G1SettingsManager.shared.quickNotes = quickNotes
        }
    }
    @Published public var batteryLevel: Int = 0
    @Published public var caseBatteryLevel: Int = 0
    @Published public var leftBatteryLevel: Int = 0
    @Published public var rightBatteryLevel: Int = 0
    @Published public var currentDashboardMode: DashboardMode = .full
    @Published public var currentMode: GlassesMode = .normal
    
    public enum AiMode: String {
        case AI_REQUESTED
        case AI_MIC_ON
        case AI_IDLE
    }
    
    let UART_SERVICE_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let UART_TX_CHAR_UUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let UART_RX_CHAR_UUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    public static let _bluetoothQueue = DispatchQueue(label: "BluetoothG1", qos: .userInitiated)
    
    public var aiMode: AiMode = .AI_IDLE {
        didSet {
            if aiMode == .AI_MIC_ON {
                aiListening = true
            } else {
                aiListening = false
            }
        }
    }
    
    private var responseModel:AiResponseToG1Model?
    private var receivedAck = false
    private var displayingResponseAiRightAck: Bool = false
    private var displayingResponseAiLeftAck: Bool = false
    
    private var evenaiSeq: UInt8 = 0
    private var centralManager: CBCentralManager!
    internal var leftPeripheral: CBPeripheral?
    internal var rightPeripheral: CBPeripheral?
    private var connectedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    
    private var aiTriggerTimeoutTimer: Timer?
    
    // Dashboard command constants
    private let DASHBOARD_COMMAND: UInt8 = 0x22
    private let DASHBOARD_POSITION_COMMAND: UInt8 = 0x26
    private let DASHBOARD_SHOW_COMMAND: UInt8 = 0x06
    private let QUICK_NOTE_COMMAND: UInt8 = 0x21
    private let DASHBOARD_CHANGE_COMMAND: [UInt8] = [0x06, 0x07, 0x00]
    private let DASHBOARD_DUAL: [UInt8] = [0x1E, 0x06, 0x01, 0x00]
    private let INIT_COMMAND: UInt8 = 0x4D
    private let START_AI_COMMAND: UInt8 = 0xF5
    private let RESPONSE_SUCCESS: UInt8 = 0xC9
    private let RESPONSE_FAILURE: UInt8 = 0xCA
    private var noteSeqId: UInt8 = 0
    
    // Battery command constants
    private let BATTERY_SUBCOMMAND: UInt8 = 0x01
    
    // Add tilt command constant
    private let TILT_ANGLE_COMMAND: UInt8 = 0x0B
    
    private var translateSeq: UInt8 = 0
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: G1BluetoothManager._bluetoothQueue)
        // Load persisted quick notes
        quickNotes = G1SettingsManager.shared.quickNotes
    }
    
    func startScan() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on.")
            return
        }
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("Scanning for devices...")
    }
    
    func connectToGlasses() {
        if let leftPeripheral = leftPeripheral {
            centralManager.connect(leftPeripheral, options: nil)
        }
        
        if let rightPeripheral = rightPeripheral {
            centralManager.connect(rightPeripheral, options: nil)
        }
        guard let leftPeripheral, let rightPeripheral else { return }
        startHeartbeatTimer()
    }
    
    private func startAITriggerTimeoutTimer() {
        let backgroundQueue = DispatchQueue(label: "com.sample.aiTriggerTimerQueue", qos: .default)
        
        backgroundQueue.async { [weak self] in
            let timer = Timer(timeInterval: 15.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                guard let rightPeripheral = self.rightPeripheral else { return }
                
                // Only stop if we're still in listening state and not in continuous mode
                if self.voiceState == .listening && !G1Controller.shared.isContinuousListening {
                    print("Voice timeout - Turning off microphone")
                    self.sendMicOn(to: rightPeripheral, isOn: false)
                    
                    if let leftChar = self.getWriteCharacteristic(for: self.leftPeripheral),
                       let rightChar = self.getWriteCharacteristic(for: rightPeripheral) {
                        self.exitAllFunctions(to: self.leftPeripheral!, characteristic: leftChar)
                        self.exitAllFunctions(to: rightPeripheral, characteristic: rightChar)
                    }
                    self.voiceState = .idle
                    self.aiState = .idle
                    self.aiListening = false
                } else if G1Controller.shared.isContinuousListening {
                    print("Ignoring voice timeout in continuous listening mode")
                }
            }
            
            self?.aiTriggerTimeoutTimer = timer
            RunLoop.current.add(timer, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    func startHeartbeatTimer() {
        let backgroundQueue = DispatchQueue(label: "com.sample.heartbeatTimerQueue", qos: .background)
        
        backgroundQueue.async { [weak self] in
            let timer = Timer(timeInterval: 15.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                guard let leftPeripheral = self.leftPeripheral else { return }
                self.sendHeartbeat(to: leftPeripheral)
                guard let rightPeripheral = self.rightPeripheral else { return }
                self.sendHeartbeat(to: rightPeripheral)
            }
            
            RunLoop.current.add(timer, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    func findCharacteristic(uuid: CBUUID, peripheral: CBPeripheral) -> CBCharacteristic? {
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == uuid {
                    return characteristic
                }
            }
        }
        return nil
    }
    
    private func getConnectedDevices() -> [CBPeripheral] {
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [UART_SERVICE_UUID])
        for peripheral in connectedPeripherals {
            print("Connected device: \(peripheral.name ?? "Unknown") - UUID: \(peripheral.identifier.uuidString)")
        }
        return connectedPeripherals
    }
    
    private var leftInitialized = false
    private var rightInitialized = false
    
    private func sendInitCommand(to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let initData = Data([INIT_COMMAND, 0x01])
        peripheral.writeValue(initData, for: characteristic, type: .withResponse)
    }
    
    private func handleInitResponse(from peripheral: CBPeripheral, success: Bool) {
        print("Received init response from \(peripheral.name ?? "Unknown"): \(success)")
        if peripheral == leftPeripheral {
            leftInitialized = success
            print("Left glass initialized: \(success)")
        } else if peripheral == rightPeripheral {
            rightInitialized = success
            print("Right glass initialized: \(success)")
        }
        
        // Only proceed if both glasses are initialized
        if leftInitialized && rightInitialized {
            print("Both glasses initialized, restoring settings...")
            g1Ready = true
            Task {
                // First fetch battery status
                await fetchBatteryStatus()
                try? await Task.sleep(nanoseconds: 200 * 1_000_000)
                
                // Then restore all saved settings with delays between commands
                await restoreSettings()
            }
        }
    }
    
    private func handleNotification(from peripheral: CBPeripheral, data: Data) {
        guard let command = data.first else { return }
        
        //print("Received command: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Handle battery status command separately as it's not in the Commands enum
        if command == 0x2C && data.count >= 2 && data[1] == 0x66 {
            if data.count >= 6 {
                let batteryPercent = Int(data[2])
                let flags = data[3]
                let voltageLow = Int(data[4])
                let voltageHigh = Int(data[5])
                let rawVoltage = (voltageHigh << 8) | voltageLow
                let voltage = rawVoltage / 10  // Scale down by 10 to get actual millivolts
                
                print("Raw battery data - Battery: \(batteryPercent)%, Voltage: \(voltage)mV, Flags: 0x\(String(format: "%02X", flags))")
                
                // Update battery level for the appropriate side
                if peripheral == leftPeripheral {
                    leftBatteryLevel = batteryPercent
                    print("Left glass battery: \(batteryPercent)%")
                } else if peripheral == rightPeripheral {
                    rightBatteryLevel = batteryPercent
                    print("Right glass battery: \(batteryPercent)%")
                }
                
                // Update the main battery level as the lower of the two
                batteryLevel = min(leftBatteryLevel, rightBatteryLevel)
            }
            return
        }
        
        if let knownCommand = Commands(rawValue: command) {
            switch knownCommand {
            case .BLE_REQ_MIC_ON:
                let acknowledge = CommandResponse(rawValue: data[1])
                if acknowledge == .ACK {
                    //print("Microphone command acknowledged")
                } else {
                    //print("Microphone command failed")
                    voiceState = .idle
                    aiState = .idle
                    aiListening = false
                }
            case .BLE_REQ_TRANSFER_MIC_DATA:
                let isContinuousEnabled = G1SettingsManager.shared.continuousListeningEnabled
                if data.count > 2 {
                    if voiceState == .listening || isContinuousEnabled {
                        // Always publish PCM data in continuous listening mode or when voice is active
                        self.voiceData = data
                        
                        // In continuous mode, ensure microphone stays on
                        if isContinuousEnabled {
                            if let rightPeripheral = self.rightPeripheral,
                               let txChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightPeripheral) {
                                let micCommand = Data([Commands.BLE_REQ_MIC_ON.rawValue, 0x01])
                                rightPeripheral.writeValue(micCommand, for: txChar, type: .withResponse)
                               //print("Maintaining microphone state in continuous mode")
                            }
                        }
                    } else {
                        print("Received PCM data in wrong state: voice=\(voiceState), ai=\(aiState), continuous=\(isContinuousEnabled)")
                    }
                }
            case .BLE_REQ_DEVICE_ORDER:
                print("Received device order: \(data.subdata(in: 1..<data.count).hexEncodedString())")
                if let order = DeviceOrders(rawValue: data[1]) {
                    switch order {
                    case .TRIGGER_FOR_AI:
                        Task {
                            if await startVoiceRecording(forAI: true) {
                                print("AI Triggered - Starting voice recording")
                            }
                        }
                    case .TRIGGER_FOR_STOP_RECORDING:
                        Task {
                            // Only stop recording if we're not in continuous listening mode
                            if !G1Controller.shared.isContinuousListening {
                                await stopVoiceRecording()
                                print("Stopping recording")
                            } else {
                                print("Ignoring stop recording trigger in continuous listening mode")
                            }
                        }
                    case .TRIGGER_CHANGE_PAGE:
                        guard var responseModel else { return }
                        print("Change Page right")
                        if responseModel.currentPage < responseModel.totalPages {
                            responseModel.currentPage += 1
                            self.responseModel = responseModel
                            Task {
                                await self.manualTextControl()
                            }
                        } else {
                            print("Change Page left")
                            if responseModel.currentPage > 1 {
                                responseModel.currentPage -= 1
                                self.responseModel = responseModel
                                Task {
                                    await self.manualTextControl()
                                }
                            }
                        }
                    case .G1_IS_READY:
                        g1Ready = true
                    case .DISPLAY_READY:
                        self.responseModel = nil
                        if G1Controller.shared.isContinuousListening {
                            // In continuous mode, just restart wake word detection
                            print("Restarting wake word detection in continuous mode")
                            G1Controller.shared.restartWakeWordDetection()
                            
                            // Ensure microphone stays on
                            if let rightPeripheral = self.rightPeripheral,
                               let txChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightPeripheral) {
                                let micCommand = Data([Commands.BLE_REQ_MIC_ON.rawValue, 0x01])
                                rightPeripheral.writeValue(micCommand, for: txChar, type: .withResponse)
                                print("Keeping microphone on for continuous listening")
                            }
                        } else {
                            // In normal mode, stop voice recording
                            Task {
                                await stopVoiceRecording()
                            }
                        }
                    }
                }
            case .BLE_REQ_EVENAI:
                if data.count > 1 {
                    let acknowledge = CommandResponse(rawValue: data[1])
                    if acknowledge == .ACK {
                        if peripheral == self.rightPeripheral {
                            self.displayingResponseAiRightAck = true
                        }
                        if peripheral == self.leftPeripheral {
                            self.displayingResponseAiLeftAck = true
                        }
                        receivedAck = self.displayingResponseAiRightAck && self.displayingResponseAiLeftAck
                    }
                }
            case .BLE_REQ_HEARTBEAT:
                // Just acknowledge heartbeat
                break
            case .BLE_REQ_INIT:
                print("Received init response: \(data.map { String(format: "%02X", $0) }.joined())")
                if data.count > 1 && data[1] == RESPONSE_SUCCESS {
                    print("Init successful")
                    g1Ready = true
                }
            case .BLE_EXIT_ALL_FUNCTIONS:
                print("Exit all functions")
            case .QUICK_NOTE_ADD:
                print("Received quick note add response: \(data.map { String(format: "%02X", $0) }.joined())")
                if data.count > 1 && data[1] == RESPONSE_SUCCESS {
                    print("Quick note add successful")
                } else if data.count > 1 && data[1] == RESPONSE_FAILURE {
                    print("Quick note add failed")
                }
            case .BATTERY_STATUS:
                if data.count >= 6 {
                    // Response format: 2C 66 [battery%] [flags] [voltage_low] [voltage_high] ...
                    let batteryPercent = Int(data[2])
                    let flags = data[3]
                    let voltageLow = Int(data[4])
                    let voltageHigh = Int(data[5])
                    let voltage = (voltageHigh << 8) | voltageLow
                    
                    print("Raw battery data - Battery: \(batteryPercent)%, Voltage: \(voltage)mV, Flags: 0x\(String(format: "%02X", flags))")
                    
                    // grab battery level from both sides
                    if peripheral == leftPeripheral {
                        leftBatteryLevel = batteryPercent
                        print("Left glass battery: \(batteryPercent)%")
                    } else if peripheral == rightPeripheral {
                        rightBatteryLevel = batteryPercent
                        print("Right glass battery: \(batteryPercent)%")
                    }
                    
                    // use the lowest battery level of the two
                    batteryLevel = min(leftBatteryLevel, rightBatteryLevel)
                }
            default:
                print("Unhandled known command: \(String(format: "%02X", command))")
            }
        } else {
            // Handle non-enum commands with better logging
            switch command {
            case START_AI_COMMAND:
                print("Received AI command: \(data.map { String(format: "%02X", $0) }.joined())")
                if data.count > 1 {
                    handleAICommand(peripheral: peripheral, subCommand: data[1])
                }
            case 0x06: // Dashboard command
                if data.count > 1 {
                    switch data[1] {
                    case 0x15: // Time/Weather update response
                        print("Received dashboard time/weather update response")
                        if data.count > 2 {
                            if data[2] == RESPONSE_SUCCESS {
                                print("Dashboard time/weather update successful")
                            } else {
                                print("Dashboard time/weather update failed with code: \(String(format: "%02X", data[2]))")
                            }
                        }
                    case 0x07: // Dashboard mode change response
                        print("Received dashboard mode change response")
                        if data.count > 2 {
                            if data[2] == RESPONSE_SUCCESS {
                                print("Dashboard mode change successful")
                            } else {
                                print("Dashboard mode change failed with code: \(String(format: "%02X", data[2]))")
                            }
                        }
                    default:
                        print("Received unknown dashboard subcommand: \(String(format: "%02X", data[1]))")
                    }
                } else {
                    print("Received incomplete dashboard command")
                }
            case DASHBOARD_COMMAND:
                print("Received dashboard response: \(data.map { String(format: "%02X", $0) }.joined())")
                if data.count > 1 && data[1] == RESPONSE_SUCCESS {
                    print("Dashboard command successful")
                }
            case QUICK_NOTE_COMMAND:
                print("Received quick note response: \(data.map { String(format: "%02X", $0) }.joined())")
                if data.count > 1 && data[1] == RESPONSE_SUCCESS {
                    print("Quick note command successful")
                } else if data.count > 1 && data[1] == RESPONSE_FAILURE {
                    print("Quick note command failed")
                }
            case 0xF5:
                if data.count >= 2 && data[1] == 0x0F {
                    // Case battery level message
                    if data.count >= 3 {
                        caseBatteryLevel = Int(data[2])
                        print("Case battery level: \(caseBatteryLevel)%")
                    }
                }
            default:
                print("Received unhandled command: \(String(format: "%02X", command)) with data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
        }
    }
    
    public func displayText(_ text: String, position: DashboardPosition = .position0) {
        guard let peripheral = position == .position0 ? rightPeripheral : leftPeripheral,
              let txCharacteristic = peripheral.services?.first(where: { $0.uuid == UART_SERVICE_UUID })?
                .characteristics?.first(where: { $0.uuid == UART_TX_CHAR_UUID }) else {
            return
        }
        
        // Set dashboard to dual mode
        let dashboardCommand = Data(DASHBOARD_DUAL)
        peripheral.writeValue(dashboardCommand, for: txCharacteristic, type: .withResponse)
        
        // Convert text to UTF-8 data
        guard let textData = text.data(using: .utf8) else { return }
        
        // Create text display command
        var command = Data()
        command.append(0x07) // Text display command
        command.append(UInt8(position.rawValue))
        command.append(UInt8(textData.count))
        command.append(textData)
        
        peripheral.writeValue(command, for: txCharacteristic, type: .withResponse)
    }
    
    public func addQuickNote(_ text: String) async {
        let note = QuickNote(id: UUID(), text: text, timestamp: Date())
        quickNotes.append(note)
        await sendQuickNotesToGlasses()
    }
    
    public func updateQuickNote(id: UUID, newText: String) async {
        if let index = quickNotes.firstIndex(where: { $0.id == id }) {
            quickNotes[index] = QuickNote(id: id, text: newText, timestamp: Date())
            await sendQuickNotesToGlasses()
        }
    }
    
    public func removeQuickNote(id: UUID) async {
        quickNotes.removeAll { $0.id == id }
        await sendQuickNotesToGlasses()
    }
    
    public func clearQuickNotes() async {
        quickNotes.removeAll()
        await sendQuickNotesToGlasses()
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            // Reset connection state
            g1Ready = false
            let devices = getConnectedDevices()
            for device in devices {
                if let name = device.name {
                    if name.contains("_L_") {
                        leftPeripheral = device
                        device.delegate = self
                        device.discoverServices([UART_SERVICE_UUID])
                    } else if name.contains("_R_") {
                        rightPeripheral = device
                        device.delegate = self
                        device.discoverServices([UART_SERVICE_UUID])
                    }
                }
            }
            if leftPeripheral == nil && rightPeripheral == nil {
                startScan()
            } else {
                connectToGlasses()
            }
        case .poweredOff:
            print("Bluetooth is powered off")
            g1Ready = false
        case .resetting:
            print("Bluetooth is resetting")
            g1Ready = false
        case .unauthorized:
            print("Bluetooth is unauthorized")
            g1Ready = false
        case .unsupported:
            print("Bluetooth is unsupported")
            g1Ready = false
        case .unknown:
            print("Bluetooth state is unknown")
            g1Ready = false
        @unknown default:
            print("Unknown bluetooth state")
            g1Ready = false
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
        
        // Update current mode and save to settings
        currentDashboardMode = mode
        G1SettingsManager.shared.dashboardMode = mode

        return true
    }

    public func fetchBatteryStatus() async {
        // Build battery status command
        let command: [UInt8] = [0x2C, 0x01]
        
        // Send to both glasses
        if let rightGlass = rightPeripheral,
           let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass) {
            rightGlass.writeValue(Data(command), for: rightTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
        }
        
        if let leftGlass = leftPeripheral,
           let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) {
            leftGlass.writeValue(Data(command), for: leftTxChar, type: .withResponse)
        }
    }

    public func sendCommand(_ command: [UInt8]) async {
        // Ensure command is exactly 20 bytes
        var paddedCommand = command
        while paddedCommand.count < 20 {
            paddedCommand.append(0x00)
        }
        
        // Convert to Data
        let commandData = Data(paddedCommand)
        print("Sending command to glasses: \(paddedCommand.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Send to right glass first
        if let rightPeripheral = rightPeripheral,
           let characteristic = rightPeripheral.services?
            .first(where: { $0.uuid == UART_SERVICE_UUID })?
            .characteristics?
            .first(where: { $0.uuid == UART_TX_CHAR_UUID }) {
            rightPeripheral.writeValue(commandData, for: characteristic, type: .withResponse)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay after sending
        }
        
        // Then send to left glass
        if let leftPeripheral = leftPeripheral,
           let characteristic = leftPeripheral.services?
            .first(where: { $0.uuid == UART_SERVICE_UUID })?
            .characteristics?
            .first(where: { $0.uuid == UART_TX_CHAR_UUID }) {
            leftPeripheral.writeValue(commandData, for: characteristic, type: .withResponse)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay after sending
        }
    }

    public func sendText(text: String, newScreen: Bool = true, currentPage: UInt8 = 1, maxPages: UInt8 = 1, isCommand: Bool = false, status: DisplayStatus = .NORMAL_TEXT) async -> Bool {
        let lines = formatTextLines(text: text)
        let totalPages = UInt8((lines.count + 3) / 4)
        evenaiSeq = 1
        let displayStatus = status
        
        // For single page
        if lines.count <= 4 {
            let displayText = lines.joined(separator: "\n")
            let result = await sendTextPacket(displayText: displayText, newScreen: true, status: displayStatus, currentPage: 1, maxPages: 1)
            return result
        } else {
            self.responseModel = AiResponseToG1Model(lines: lines, totalPages: totalPages, newScreen: true, currentPage: currentPage, maxPages: totalPages, status: displayStatus)
            return await self.manualTextControl()
        }
    }
    
    private func sendTextPacket(displayText: String, newScreen: Bool, status: DisplayStatus, currentPage: UInt8, maxPages: UInt8) async -> Bool {
        guard let textData = displayText.data(using: .utf8) else { return false }
        let chunks = textData.chunked(into: 191)
        
        for (i, chunk) in chunks.enumerated() {
            // Reset acknowledgment flags
            receivedAck = false
            displayingResponseAiRightAck = false
            displayingResponseAiLeftAck = false
            
            // First send the text display command
            var displayCommand = Data()
            displayCommand.append(0x4E) // Text display command
            displayCommand.append(0x71) // Direct text subcode
            displayCommand.append(UInt8(chunk.count)) // Text length
            displayCommand.append(chunk)
            
            if let leftChar = getWriteCharacteristic(for: leftPeripheral),
               let rightChar = getWriteCharacteristic(for: rightPeripheral) {
                
                // Send display command to both glasses
                rightPeripheral?.writeValue(displayCommand, for: rightChar, type: .withResponse)
                try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
                leftPeripheral?.writeValue(displayCommand, for: leftChar, type: .withResponse)
                try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
                
                // Then send the AI packet for proper display state
                let header = Data([Commands.BLE_REQ_EVENAI.rawValue, evenaiSeq, UInt8(chunks.count), UInt8(i), status.rawValue | (newScreen ? 1 : 0), 0, 0, currentPage, maxPages])
                let aiPacket = header + chunk
                
                // Try up to 3 times for each glass
                for attempt in 1...3 {
                    print("Attempt \(attempt) to send text packet")
                    
                    rightPeripheral?.writeValue(aiPacket, for: rightChar, type: .withResponse)
                    try? await Task.sleep(nanoseconds: 20 * 1_000_000) // 20ms delay
                    leftPeripheral?.writeValue(aiPacket, for: leftChar, type: .withResponse)
                    
                    // Wait for acknowledgments
                    let ackTimeout = 0.3 // 300ms timeout
                    let startTime = Date()
                    
                    while Date().timeIntervalSince(startTime) < ackTimeout {
                        if displayingResponseAiRightAck && displayingResponseAiLeftAck {
                            print("Both glasses acknowledged packet")
                            receivedAck = true
                            break
                        }
                        try? await Task.sleep(nanoseconds: 10 * 1_000_000) // 10ms check interval
                    }
                    
                    if receivedAck {
                        break // Success, move to next chunk
                    } else {
                        print("Attempt \(attempt) failed. Right ack: \(displayingResponseAiRightAck), Left ack: \(displayingResponseAiLeftAck)")
                        if attempt == 3 {
                            print("Failed to get acknowledgment from glasses after 3 attempts")
                            return false
                        }
                        // Reset flags for next attempt
                        displayingResponseAiRightAck = false
                        displayingResponseAiLeftAck = false
                        try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay before retry
                    }
                }
                evenaiSeq += 1
            }
        }
        return true
    }

    public func setBrightness(_ level: UInt8, autoMode: Bool = false) async -> Bool {
        // Ensure level is between 0x00 and 0x29 (0-41)
        guard level <= 0x29 else { return false }
        
        let command: [UInt8] = [Commands.BRIGHTNESS.rawValue, level, autoMode ? 0x01 : 0x00]
        
        // Send to both glasses with proper timing
        if let rightGlass = rightPeripheral,
           let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass) {
            rightGlass.writeValue(Data(command), for: rightTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
        }
        
        if let leftGlass = leftPeripheral,
           let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) {
            leftGlass.writeValue(Data(command), for: leftTxChar, type: .withResponse)
        }
        
        // Save brightness settings - fix arithmetic overflow
        let brightnessPercentage = Int((Double(level) / 41.0) * 100.0)
        G1SettingsManager.shared.brightness = brightnessPercentage
        G1SettingsManager.shared.autoBrightnessEnabled = autoMode
        return true
    }
    
    public func setSilentMode(_ enabled: Bool) async -> Bool {
        let command: [UInt8] = [Commands.SILENT_MODE.rawValue, enabled ? 0x0C : 0x0A, 0x00]
        
        // Send to both glasses with proper timing
        if let rightGlass = rightPeripheral,
           let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass) {
            rightGlass.writeValue(Data(command), for: rightTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
        }
        
        if let leftGlass = leftPeripheral,
           let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) {
            leftGlass.writeValue(Data(command), for: leftTxChar, type: .withResponse)
        }
        
        // Save silent mode setting
        G1SettingsManager.shared.silentModeEnabled = enabled
        return true
    }

    public func setDashboardPosition(_ position: DashboardPosition) async -> Bool {
        guard let rightGlass = rightPeripheral,
              let leftGlass = leftPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
              let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) else {
            return false
        }

        // Build dashboard position command
        var command = Data()
        command.append(DASHBOARD_POSITION_COMMAND)
        command.append(0x07) // Length
        command.append(0x00) // Sequence
        command.append(0x01) // Fixed value
        command.append(0x02) // Fixed value
        command.append(0x01) // State ON
        command.append(position.rawValue) // Position value

        // Send command to both glasses with proper timing
        rightGlass.writeValue(command, for: rightTxChar, type: .withResponse)
        try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
        leftGlass.writeValue(command, for: leftTxChar, type: .withResponse)

        // Save position to settings
        G1SettingsManager.shared.dashboardHeight = Int(position.rawValue)
        return true
    }

    public func hideDashboard() async -> Bool {
        guard let rightGlass = rightPeripheral,
              let leftGlass = leftPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
              let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) else {
            return false
        }

        // Build dashboard hide command
        var command = Data()
        command.append(DASHBOARD_POSITION_COMMAND)
        command.append(0x07) // Length
        command.append(0x00) // Sequence
        command.append(0x01) // Fixed value
        command.append(0x02) // Fixed value
        command.append(0x00) // State OFF
        command.append(0x00) // Position doesn't matter when hiding

        // Send command to both glasses with proper timing
        rightGlass.writeValue(command, for: rightTxChar, type: .withResponse)
        try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
        leftGlass.writeValue(command, for: leftTxChar, type: .withResponse)

        return true
    }

    public func setDashboardDistance(_ distance: UInt8) async -> Bool {
        guard let rightGlass = rightPeripheral,
              let leftGlass = leftPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
              let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) else {
            return false
        }

        let clampedDistance = min(max(distance, 1), 9)
        
        // Build dashboard distance command
        var command = Data()
        command.append(DASHBOARD_POSITION_COMMAND) // 0x26
        command.append(0x80) // Length high byte
        command.append(0x00) // Length low byte
        command.append(0x00) // Sequence number
        command.append(0x02) // Sub-command
        command.append(0x01) // Active state
        command.append(0x04) // Current vertical position
        command.append(clampedDistance)

        // Send command to both glasses with proper timing
        rightGlass.writeValue(command, for: rightTxChar, type: .withResponse)
        try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
        leftGlass.writeValue(command, for: leftTxChar, type: .withResponse)

        // Save distance to settings
        G1SettingsManager.shared.dashboardDistance = Int(clampedDistance)
        return true
    }

    public func setTiltAngle(_ degrees: UInt8) async -> Bool {
        guard let rightGlass = rightPeripheral,
              let leftGlass = leftPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
              let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) else {
            return false
        }

        // Ensure angle is within valid range (0-60 degrees)
        let clampedDegrees = min(max(degrees, 0), 60)

        // Build tilt angle command
        var command = Data()
        command.append(TILT_ANGLE_COMMAND) // 0x0B
        command.append(clampedDegrees) // Angle in degrees (0x00-0x3C)
        command.append(0x01) // Fixed value

        // Send command to both glasses with proper timing
        rightGlass.writeValue(command, for: rightTxChar, type: .withResponse)
        try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms delay
        leftGlass.writeValue(command, for: leftTxChar, type: .withResponse)

        // Save tilt angle to settings
        G1SettingsManager.shared.dashboardTilt = Int(clampedDegrees)
        return true
    }

    private func nextTranslateSeq() -> UInt8 {
        translateSeq += 1
        if translateSeq > 255 {
            translateSeq = 0
        }
        return translateSeq
    }

    // Translation Flow:
    // 1. Call startTranslation() with source/target languages to initialize
    // 2. Call sendTranslation() with original and translated text pairs
    // 3. Sequence numbers (0-255) automatically cycle to track message order
    // Implementation based on Fahrplan's translation code
    public func startTranslation(from sourceLanguage: TranslateLanguage, to targetLanguage: TranslateLanguage) async -> Bool {
        // Set mode to translation
        currentMode = .translation
        
        // Setup translation mode
        let setupCommand = Data([Commands.TRANSLATE_SETUP.rawValue, 0x05, 0x00, 0x00, 0x13])
        await sendCommand(Array(setupCommand))
        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
        
        // Start translation on right glass
        if let rightGlass = rightPeripheral,
           let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass) {
            let startCommand = Data([Commands.TRANSLATE_START.rawValue, 0x06, 0x00, 0x00, 0x01, 0x01])
            rightGlass.writeValue(startCommand, for: rightTxChar, type: .withResponse)
        }
        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
        
        // Configure languages
        let configCommand = Data([Commands.TRANSLATE_CONFIG.rawValue, 0x00, sourceLanguage.rawValue, targetLanguage.rawValue])
        await sendCommand(Array(configCommand))
        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
        
        // Initialize text display for original text
        let initOriginal = Data([Commands.TRANSLATE_ORIGINAL.rawValue, nextTranslateSeq(), 0x01, 0x00, 0x00, 0x00, 0x00, 0x0D])
        await sendCommand(Array(initOriginal))
        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
        
        // Initialize text display for translated text
        let initTranslated = Data([Commands.TRANSLATE_TRANSLATED.rawValue, nextTranslateSeq(), 0x01, 0x00, 0x00, 0x00, 0x00, 0x0D])
        await sendCommand(Array(initTranslated))
        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
        
        return true
    }
    
    public func sendTranslation(originalText: String, translatedText: String) async -> Bool {
        guard let originalData = originalText.data(using: .utf8),
              let translatedData = translatedText.data(using: .utf8) else {
            return false
        }
        
        // Send original text
        var originalCommand = Data([Commands.TRANSLATE_ORIGINAL.rawValue, nextTranslateSeq(), 0x01, 0x00, 0x00, 0x00, 0x20, 0x0D])
        originalCommand.append(originalData)
        await sendCommand(Array(originalCommand))
        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
        
        // Send translated text
        var translatedCommand = Data([Commands.TRANSLATE_TRANSLATED.rawValue, nextTranslateSeq(), 0x01, 0x00, 0x00, 0x00, 0x20, 0x0D])
        translatedCommand.append(translatedData)
        await sendCommand(Array(translatedCommand))
        
        return true
    }
    // Exits the translation screen
    public func stopTranslation() async {
        if let rightPeripheral = rightPeripheral {
            sendMicOn(to: rightPeripheral, isOn: false)
        }
        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
        await sendCommand([Commands.BLE_EXIT_ALL_FUNCTIONS.rawValue])
        
        // Reset mode to normal
        currentMode = .normal
    }

    private func sendMicOn(to peripheral: CBPeripheral, isOn: Bool) {
        if let txChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: peripheral) {
            var command = Data()
            command.append(Commands.BLE_REQ_MIC_ON.rawValue)
            command.append(isOn ? 0x01 : 0x00)
            peripheral.writeValue(command, for: txChar, type: .withResponse)
            
            if !isOn {
                exitAllFunctions(to: peripheral, characteristic: txChar)
                print("Microphone turned OFF")
                voiceState = .idle
                aiState = .idle
                aiListening = false
            } else {
                if G1Controller.shared.isContinuousListening {
                    print("Microphone turned ON - Continuous Listening")
                    // Don't set voiceState to listening in continuous mode
                    // This allows wake word detection to work without interfering with AI state
                } else {
                    print("Microphone turned ON - Voice Active")
                    voiceState = .listening
                    if aiState != .idle {
                        aiListening = true
                    }
                }
            }
        }
    }

    public func startVoiceRecording(forAI: Bool = false) async -> Bool {
        guard let rightPeripheral = rightPeripheral else { return false }
        
        if !g1Ready {
            print("Cannot start voice recording - glasses not ready")
            return false
        }
        
        if voiceState == .listening && !G1Controller.shared.isContinuousListening {
            print("Voice recording already active")
            return false
        }
        
        if forAI {
            aiState = .active
            voiceState = .listening // Set voice state to listening only when AI is active
        }
        
        sendMicOn(to: rightPeripheral, isOn: true)
        if forAI {
            startAITriggerTimeoutTimer()
        }
        return true
    }

    public func stopVoiceRecording() async {
        if let rightPeripheral = rightPeripheral {
            sendMicOn(to: rightPeripheral, isOn: false)
        }
        aiTriggerTimeoutTimer?.invalidate()
        aiTriggerTimeoutTimer = nil
        
        voiceState = .idle
        aiState = .idle
        aiListening = false
    }

    public func updateVoiceState(_ state: VoiceState) {
        voiceState = state
    }
}

// MARK: Commands
extension G1BluetoothManager {
    
    func exitAllFunctions(to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        var data = Data()
        data.append(Commands.BLE_EXIT_ALL_FUNCTIONS.rawValue)
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }
    
    private func sendHeartbeat(to peripheral: CBPeripheral) {
        var heartbeatData = Data()
        heartbeatData.append(Commands.BLE_REQ_HEARTBEAT.rawValue)
        heartbeatData.append(UInt8(0x02 & 0xFF))

        if let txChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: peripheral) {
            let hexString = heartbeatData.map { String(format: "%02X", $0) }.joined()
            //print("Hex String Send: \(hexString)")
            peripheral.writeValue(heartbeatData, for: txChar, type: .withoutResponse)
        }
    }
    
    private func formatTextLines(text: String) -> [String] {
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        var lines = [String]()
        
        for paragraph in paragraphs {
            if paragraph.isEmpty {
                lines.append(paragraph) // Keep empty lines for spacing
                continue
            }
            
            var remainingText = paragraph
            while remainingText.count > 40 {
                // Try to find a space to break at
                var endIndex = remainingText.index(remainingText.startIndex, offsetBy: 40)
                while endIndex > remainingText.startIndex && !remainingText[endIndex].isWhitespace {
                    endIndex = remainingText.index(before: endIndex)
                }
                
                // If no space found, force break at 40
                if endIndex == remainingText.startIndex {
                    endIndex = remainingText.index(remainingText.startIndex, offsetBy: 40)
                }
                
                let line = String(remainingText[..<endIndex])
                lines.append(line)
                
                // Skip the space we broke at
                if remainingText[endIndex].isWhitespace {
                    endIndex = remainingText.index(after: endIndex)
                }
                remainingText = String(remainingText[endIndex...])
            }
            if !remainingText.isEmpty {
                lines.append(remainingText)
            }
        }
        return lines
    }
    
    private func manualTextControl() async -> Bool {
        guard let responseModel else { return false }
        let lines = responseModel.lines
        let start_idx = Int((responseModel.currentPage - 1) * 4)
        let pageLines = lines[start_idx..<min(start_idx + 4, lines.count)]
        let displayText = pageLines.joined(separator: "\n")
        
        // Send text packet only once with proper synchronization
        return await sendTextPacket(displayText: displayText, newScreen: true, status: responseModel.status, currentPage: responseModel.currentPage, maxPages: responseModel.totalPages)
    }
    
    private func handleAICommand(peripheral: CBPeripheral, subCommand: UInt8) {
        // Don't process AI commands that would stop recording in continuous mode
        if G1Controller.shared.isContinuousListening && (subCommand == 0x00 || subCommand == 0x18) {
            print("Ignoring AI exit command in continuous listening mode")
            return
        }

        switch subCommand {
        case 0x00:
            print("Exit to dashboard manually")
            if !G1Controller.shared.isContinuousListening {
                aiMode = .AI_IDLE
            }
        case 0x01:
            print("Page control")
            if !G1Controller.shared.isContinuousListening {
                aiMode = .AI_IDLE
            }
        case 0x17: // 23 in decimal
            print("Start Even AI")
            aiMode = .AI_REQUESTED
        case 0x18: // 24 in decimal
            print("Stop Even AI recording")
            if !G1Controller.shared.isContinuousListening {
                aiMode = .AI_IDLE
            } else {
                // In continuous mode, keep the mic on and restart wake word detection
                Task {
                    if let rightPeripheral = self.rightPeripheral,
                       let txChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightPeripheral) {
                        let micCommand = Data([Commands.BLE_REQ_MIC_ON.rawValue, 0x01])
                        rightPeripheral.writeValue(micCommand, for: txChar, type: .withResponse)
                        print("Keeping microphone on in continuous mode")
                        G1Controller.shared.restartWakeWordDetection()
                    }
                }
            }
        default:
            print("Unknown AI subcommand: \(String(format: "%02X", subCommand))")
        }
    }
}

// MARK: BLE Stubs
extension G1BluetoothManager {
    
    func getWriteCharacteristic(for peripheral: CBPeripheral?) -> CBCharacteristic? {
        guard let peripheral = peripheral else { return nil }
        for service in peripheral.services ?? [] {
            if service.uuid == UART_SERVICE_UUID {
                for characteristic in service.characteristics ?? [] where characteristic.uuid == UART_TX_CHAR_UUID {
                    return characteristic
                }
            }
        }
        return nil
    }
    
    private func sendQuickNotesToGlasses() async {
        guard let rightGlass = rightPeripheral,
              let leftGlass = leftPeripheral,
              let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
              let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) else {
            return
        }
        
        // First, clear all existing notes
        for noteNumber in 1...4 {
            var command = Data()
            command.append(Commands.QUICK_NOTE_ADD.rawValue)
            command.append(0x10) // Fixed length for delete command
            command.append(0x00) // Fixed byte
            command.append(0xE0) // Version byte for delete
            command.append(contentsOf: [0x03, 0x01, 0x00, 0x01, 0x00]) // Fixed bytes
            command.append(UInt8(noteNumber)) // Note number to delete
            command.append(contentsOf: [0x00, 0x01, 0x00, 0x01, 0x00, 0x00]) // Fixed bytes for delete
            
            // Send delete command to both glasses with proper timing
            rightGlass.writeValue(command, for: rightTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000)
            leftGlass.writeValue(command, for: leftTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 150 * 1_000_000)
        }
        
        // Then add all current notes
        for (index, note) in quickNotes.prefix(4).enumerated() {
            let slotNumber = index + 1
            
            guard let textData = note.text.data(using: .utf8),
                  let nameData = "Quick Note".data(using: .utf8) else {
                continue
            }
            
            // Calculate payload length
            let fixedBytes: [UInt8] = [0x03, 0x01, 0x00, 0x01, 0x00]
            let versionByte = UInt8(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 256))
            let payloadLength = 1 + // Fixed byte
                               1 + // Version byte
                               fixedBytes.count + // Fixed bytes sequence
                               1 + // Note number
                               1 + // Fixed byte 2
                               1 + // Name length
                               nameData.count + // Name bytes
                               1 + // Text length
                               1 + // Fixed byte after text length
                               textData.count + // Text bytes
                               2 // Final bytes
            
            // Build command
            var command = Data()
            command.append(Commands.QUICK_NOTE_ADD.rawValue)
            command.append(UInt8(payloadLength & 0xFF))
            command.append(0x00) // Fixed byte
            command.append(versionByte)
            command.append(contentsOf: fixedBytes)
            command.append(UInt8(slotNumber))
            command.append(0x01) // Fixed byte 2
            command.append(UInt8(nameData.count))
            command.append(nameData)
            command.append(UInt8(textData.count))
            command.append(0x00) // Fixed byte
            command.append(textData)
            
            // Send to both peripherals
            rightGlass.writeValue(command, for: rightTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000)
            leftGlass.writeValue(command, for: leftTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 150 * 1_000_000)
        }
    }
    
    func writePacket(peripheral: CBPeripheral? ,_ packet: Data, to characteristic: CBCharacteristic) async -> Bool {
        guard let peripheral else { return false }
        
        peripheral.writeValue(packet, for: characteristic, type: .withResponse)
        let timeoutDuration = 0.3  // 300ms timeout
        let timeoutDate = Date().addingTimeInterval(timeoutDuration)
        
        while Date() < timeoutDate {
            if peripheral == leftPeripheral && displayingResponseAiLeftAck {
                return true
            } else if peripheral == rightPeripheral && displayingResponseAiRightAck {
                return true
            }
            try? await Task.sleep(nanoseconds: 10 * 1_000_000) // 10ms check interval
        }
        
        if peripheral == leftPeripheral {
            print("Left glass acknowledgment timeout")
        } else {
            print("Right glass acknowledgment timeout")
        }
        return false
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name {
            if name.contains("_L_") {
                leftPeripheral = peripheral
            } else if name.contains("_R_") {
                rightPeripheral = peripheral
            }
            
            if leftPeripheral != nil && rightPeripheral != nil {
                central.stopScan()
                connectToGlasses()
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        peripheral.delegate = self
        peripheral.discoverServices([UART_SERVICE_UUID])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "No error")")
        // Reset initialization state and g1Ready
        if peripheral == leftPeripheral {
            leftInitialized = false
        } else if peripheral == rightPeripheral {
            rightInitialized = false
        }
        g1Ready = false
        
        // Attempt to reconnect
        if peripheral == leftPeripheral || peripheral == rightPeripheral {
            central.connect(peripheral, options: nil)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error)")
            return
        }
        
        guard let services = peripheral.services else { return }
        print("Discovered services for \(peripheral.name ?? "Unknown Device")")
        
        for service in services {
            if service.uuid == UART_SERVICE_UUID {
                print("Found UART service")
                peripheral.discoverCharacteristics([UART_TX_CHAR_UUID, UART_RX_CHAR_UUID], for: service)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        print("Discovered characteristics for \(peripheral.name ?? "Unknown Device")")

                for characteristic in characteristics {
                    if characteristic.uuid == UART_TX_CHAR_UUID {
                print("Found TX characteristic")
                        sendInitCommand(to: peripheral, characteristic: characteristic)
                    } else if characteristic.uuid == UART_RX_CHAR_UUID {
                print("Found RX characteristic, enabling notifications")
                        peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error changing notification state: \(error)")
            return
        }
        
        print("Notification state updated for \(peripheral.name ?? "Unknown Device"): \(characteristic.isNotifying)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error receiving data: \(error)")
            return
        }
        
        guard let data = characteristic.value else { return }
        guard data.count > 0 else { return }
        
        handleNotification(from: peripheral, data: data)
    }
    
    private func restoreSettings() async {
        let settings = G1SettingsManager.shared
        print("Starting settings restoration...")
        
        // Add delay between each command to ensure proper processing
        try? await Task.sleep(nanoseconds: 500 * 1_000_000) // 500ms initial delay
        
        // First set dashboard mode as it affects overall display
        print("Restoring dashboard mode...")
        await setDashboardMode(settings.dashboardMode)
        try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        
        // Reset dashboard position to default to allow manual adjustment
        print("Resetting dashboard position to allow manual adjustment...")
        var command = Data()
        command.append(DASHBOARD_POSITION_COMMAND)
        command.append(0x07) // Length
        command.append(0x00) // Sequence
        command.append(0x01) // Fixed value
        command.append(0x02) // Fixed value
        command.append(0x00) // State OFF - This will allow manual positioning
        command.append(0x00) // Position value doesn't matter when state is OFF
        
        if let rightGlass = rightPeripheral,
           let leftGlass = leftPeripheral,
           let rightTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: rightGlass),
           let leftTxChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: leftGlass) {
            rightGlass.writeValue(command, for: rightTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000)
            leftGlass.writeValue(command, for: leftTxChar, type: .withResponse)
            try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        }
        
        // Restore brightness and auto-brightness
        print("Restoring brightness to: \(settings.brightness)% with auto mode: \(settings.autoBrightnessEnabled)")
        let brightnessLevel = UInt8((Double(settings.brightness) / 100.0) * 41.0)
        await setBrightness(brightnessLevel, autoMode: settings.autoBrightnessEnabled)
        try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        
        // Restore silent mode
        print("Restoring silent mode: \(settings.silentModeEnabled)")
        await setSilentMode(settings.silentModeEnabled)
        try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        
        // Restore weather and time format settings
        print("Restoring weather enabled: \(settings.weatherEnabled)")
        if settings.weatherEnabled {
            G1Controller.shared.configureWeather()
            try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        }
        
        print("Restoring time format 24h: \(settings.use24Hour)")
        G1Controller.shared.setTimeFormat(use24Hour: settings.use24Hour)
        try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        
        print("Restoring temperature unit Fahrenheit: \(settings.useFahrenheit)")
        G1Controller.shared.setTemperatureUnit(useFahrenheit: settings.useFahrenheit)
        try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        
        // Restore continuous listening if it was enabled
        if settings.continuousListeningEnabled {
            print("Restoring continuous listening mode...")
            await G1Controller.shared.toggleContinuousListening()
            try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        }
        
        // Restore quick notes last since they're the most visible change
        if !settings.quickNotes.isEmpty {
            print("Restoring \(settings.quickNotes.count) quick notes...")
            await sendQuickNotesToGlasses()
        }
        
        print("Settings restoration completed.")
    }
}
