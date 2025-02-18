import Foundation

// Since we're in the same module (CoreSwift), we don't need to import these types
public final class G1SettingsManager {
    public static let shared = G1SettingsManager()
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let apiEndpoint = "apiEndpoint"
        static let apiKey = "apiKey"
        static let selectedModel = "selectedModel"
        static let useFahrenheit = "useFahrenheit"
        static let use24Hour = "use24Hour"
        static let weatherEnabled = "weatherEnabled"
        static let continuousListeningEnabled = "continuousListeningEnabled"
        static let silentModeEnabled = "silentModeEnabled"
        static let brightness = "brightness"
        static let autoBrightnessEnabled = "autoBrightnessEnabled"
        static let dashboardMode = "dashboardMode"
        static let dashboardHeight = "dashboardHeight"
        static let dashboardDistance = "dashboardDistance"
        static let dashboardTilt = "dashboardTilt"
        static let quickNotes = "quickNotes"
        static let lastWeatherCode = "lastWeatherCode"
        static let lastTemperatureCelsius = "lastTemperatureCelsius"
        static let hasWeatherData = "hasWeatherData"
        static let lastWeatherUpdateTime = "lastWeatherUpdateTime"
    }
    
    // MARK: - Properties with Persistence
    
    public var apiEndpoint: String? {
        get { UserDefaults.standard.string(forKey: Keys.apiEndpoint) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.apiEndpoint) }
    }
    
    public var apiKey: String? {
        get { UserDefaults.standard.string(forKey: Keys.apiKey) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.apiKey) }
    }
    
    public var selectedModel: String? {
        get { UserDefaults.standard.string(forKey: Keys.selectedModel) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.selectedModel) }
    }
    
    public var useFahrenheit: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.useFahrenheit) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.useFahrenheit) }
    }
    
    public var use24Hour: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.use24Hour) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.use24Hour) }
    }
    
    public var weatherEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.weatherEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.weatherEnabled) }
    }
    
    public var continuousListeningEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.continuousListeningEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.continuousListeningEnabled) }
    }
    
    public var silentModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.silentModeEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.silentModeEnabled) }
    }
    
    public var brightness: Int {
        get { UserDefaults.standard.integer(forKey: Keys.brightness) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.brightness) }
    }
    
    public var autoBrightnessEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.autoBrightnessEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoBrightnessEnabled) }
    }
    
    public var dashboardMode: DashboardMode {
        get {
            let rawValue = UserDefaults.standard.integer(forKey: Keys.dashboardMode)
            return DashboardMode(rawValue: UInt8(rawValue)) ?? .full
        }
        set { UserDefaults.standard.set(Int(newValue.rawValue), forKey: Keys.dashboardMode) }
    }
    
    public var dashboardHeight: Int {
        get { UserDefaults.standard.integer(forKey: Keys.dashboardHeight) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.dashboardHeight) }
    }
    
    public var dashboardDistance: Int {
        get { UserDefaults.standard.integer(forKey: Keys.dashboardDistance) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.dashboardDistance) }
    }
    
    public var dashboardTilt: Int {
        get { UserDefaults.standard.integer(forKey: Keys.dashboardTilt) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.dashboardTilt) }
    }
    
    public var lastWeatherCode: Int {
        get { UserDefaults.standard.integer(forKey: Keys.lastWeatherCode) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastWeatherCode) }
    }
    
    public var lastTemperatureCelsius: Double {
        get { UserDefaults.standard.double(forKey: Keys.lastTemperatureCelsius) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastTemperatureCelsius) }
    }
    
    public var hasWeatherData: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasWeatherData) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasWeatherData) }
    }
    
    public var lastWeatherUpdateTime: TimeInterval? {
        get { UserDefaults.standard.object(forKey: Keys.lastWeatherUpdateTime) as? TimeInterval }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastWeatherUpdateTime) }
    }
    
    // MARK: - Quick Notes Persistence
    
    public var quickNotes: [QuickNote] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.quickNotes),
                  let notes = try? JSONDecoder().decode([QuickNotePersistence].self, from: data) else {
                return []
            }
            return notes.map { $0.toQuickNote() }
        }
        set {
            let persistenceNotes = newValue.map { QuickNotePersistence(from: $0) }
            if let data = try? JSONEncoder().encode(persistenceNotes) {
                UserDefaults.standard.set(data, forKey: Keys.quickNotes)
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Set default values if not already set
        if UserDefaults.standard.object(forKey: Keys.dashboardDistance) == nil {
            UserDefaults.standard.set(4, forKey: Keys.dashboardDistance) // Default 4m
        }
        if UserDefaults.standard.object(forKey: Keys.dashboardTilt) == nil {
            UserDefaults.standard.set(30, forKey: Keys.dashboardTilt) // Default 30°
        }
        if UserDefaults.standard.object(forKey: Keys.dashboardHeight) == nil {
            UserDefaults.standard.set(0, forKey: Keys.dashboardHeight) // Default Level 0
        }
        if UserDefaults.standard.object(forKey: Keys.brightness) == nil {
            UserDefaults.standard.set(50, forKey: Keys.brightness) // Default 50%
        }
        if UserDefaults.standard.object(forKey: Keys.quickNotes) == nil {
            UserDefaults.standard.set(Data(), forKey: Keys.quickNotes) // Empty quick notes array
        }
    }
    
    // MARK: - Helper Methods
    
    public func clearAllSettings() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
}

// MARK: - Quick Note Persistence Model
private struct QuickNotePersistence: Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    
    init(from note: QuickNote) {
        self.id = note.id
        self.text = note.text
        self.timestamp = note.timestamp
    }
    
    func toQuickNote() -> QuickNote {
        return QuickNote(id: id, text: text, timestamp: timestamp)
    }
} 