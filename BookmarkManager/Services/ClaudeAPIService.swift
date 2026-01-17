import Foundation

class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    // Models
    enum Model: String {
        case haiku = "claude-3-haiku-20240307"
        case sonnet = "claude-sonnet-4-20250514"
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct APIRequest: Codable {
        let model: String
        let max_tokens: Int
        let messages: [Message]
        let system: String?
    }

    struct APIResponse: Codable {
        let content: [ContentBlock]
        let usage: Usage?

        struct ContentBlock: Codable {
            let type: String
            let text: String?
        }

        struct Usage: Codable {
            let input_tokens: Int
            let output_tokens: Int
        }
    }

    struct APIError: Codable {
        let error: ErrorDetail

        struct ErrorDetail: Codable {
            let type: String
            let message: String
        }
    }

    enum ClaudeError: Error, LocalizedError {
        case noAPIKey
        case invalidResponse
        case apiError(String)
        case networkError(Error)
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key configured. Please add your Claude API key in Settings."
            case .invalidResponse:
                return "Invalid response from Claude API"
            case .apiError(let message):
                return "API Error: \(message)"
            case .networkError(let error):
                return "Network Error: \(error.localizedDescription)"
            case .rateLimited:
                return "Rate limited. Please wait a moment and try again."
            }
        }
    }

    private init() {}

    // MARK: - Public API

    /// Send a message to Claude and get a response
    func sendMessage(
        prompt: String,
        systemPrompt: String? = nil,
        model: Model = .haiku,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard let apiKey = KeychainService.shared.getClaudeAPIKey() else {
            throw ClaudeError.noAPIKey
        }

        let request = APIRequest(
            model: model.rawValue,
            max_tokens: maxTokens,
            messages: [Message(role: "user", content: prompt)],
            system: systemPrompt
        )

        return try await makeRequest(request, apiKey: apiKey)
    }

    /// Send a conversation with multiple messages
    func sendConversation(
        messages: [Message],
        systemPrompt: String? = nil,
        model: Model = .sonnet,
        maxTokens: Int = 2048
    ) async throws -> String {
        guard let apiKey = KeychainService.shared.getClaudeAPIKey() else {
            throw ClaudeError.noAPIKey
        }

        let request = APIRequest(
            model: model.rawValue,
            max_tokens: maxTokens,
            messages: messages,
            system: systemPrompt
        )

        return try await makeRequest(request, apiKey: apiKey)
    }

    /// Test if the API key is valid
    func testAPIKey(_ apiKey: String) async -> Bool {
        let request = APIRequest(
            model: Model.haiku.rawValue,
            max_tokens: 10,
            messages: [Message(role: "user", content: "Hi")],
            system: nil
        )

        do {
            _ = try await makeRequest(request, apiKey: apiKey)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private

    private func makeRequest(_ request: APIRequest, apiKey: String) async throws -> String {
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw ClaudeError.rateLimited
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ClaudeError.apiError(errorResponse.error.message)
            }
            throw ClaudeError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)

        guard let text = apiResponse.content.first?.text else {
            throw ClaudeError.invalidResponse
        }

        return text
    }
}
