import Foundation

public enum AppConfig {
    public static var llmConfig: LLMConfig {
        return LLMConfig(
            baseURL: ProcessInfo.processInfo.environment["LLM_API_URL"] ?? "https://api.openai.com/v1/chat/completions",
            apiKey: ProcessInfo.processInfo.environment["LLM_API_KEY"] ?? ""
        )
    }
}

public struct LLMConfig {
    public let baseURL: String
    public let apiKey: String
    
    public init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
} 