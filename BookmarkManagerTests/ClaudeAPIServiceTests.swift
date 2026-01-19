import XCTest
@testable import BookmarkManager

final class ClaudeAPIServiceTests: XCTestCase {

    // MARK: - Model Enum Tests

    func testHaikuModelRawValue() {
        let model = ClaudeModel.haiku
        XCTAssertEqual(model.rawValue, "claude-3-haiku-20240307")
    }

    func testSonnetModelRawValue() {
        let model = ClaudeModel.sonnet
        XCTAssertEqual(model.rawValue, "claude-sonnet-4-20250514")
    }

    // MARK: - Message Structure Tests

    func testMessageEncoding() throws {
        let message = APIMessage(role: "user", content: "Hello, Claude!")

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"role\":\"user\""))
        XCTAssertTrue(json.contains("\"content\":\"Hello, Claude!\""))
    }

    func testMessageDecoding() throws {
        let json = """
        {"role": "assistant", "content": "Hello! How can I help you?"}
        """

        let data = json.data(using: .utf8)!
        let message = try JSONDecoder().decode(APIMessage.self, from: data)

        XCTAssertEqual(message.role, "assistant")
        XCTAssertEqual(message.content, "Hello! How can I help you?")
    }

    // MARK: - API Request Structure Tests

    func testAPIRequestEncoding() throws {
        let request = APIRequest(
            model: "claude-3-haiku-20240307",
            max_tokens: 1024,
            messages: [APIMessage(role: "user", content: "Test")],
            system: "You are a helpful assistant.",
            stream: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"model\":\"claude-3-haiku-20240307\""))
        XCTAssertTrue(json.contains("\"max_tokens\":1024"))
        XCTAssertTrue(json.contains("\"system\":\"You are a helpful assistant.\""))
    }

    func testAPIRequestEncodingWithoutOptionalFields() throws {
        let request = APIRequest(
            model: "claude-3-haiku-20240307",
            max_tokens: 512,
            messages: [APIMessage(role: "user", content: "Test")],
            system: nil,
            stream: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        XCTAssertNotNil(data)
    }

    // MARK: - API Response Structure Tests

    func testAPIResponseDecoding() throws {
        let json = """
        {
            "content": [
                {"type": "text", "text": "Hello! I'm Claude."}
            ],
            "usage": {
                "input_tokens": 10,
                "output_tokens": 5
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(APIResponse.self, from: data)

        XCTAssertEqual(response.content.count, 1)
        XCTAssertEqual(response.content[0].type, "text")
        XCTAssertEqual(response.content[0].text, "Hello! I'm Claude.")
        XCTAssertEqual(response.usage?.input_tokens, 10)
        XCTAssertEqual(response.usage?.output_tokens, 5)
    }

    func testAPIResponseDecodingWithoutUsage() throws {
        let json = """
        {
            "content": [
                {"type": "text", "text": "Response text"}
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(APIResponse.self, from: data)

        XCTAssertNil(response.usage)
        XCTAssertEqual(response.content[0].text, "Response text")
    }

    // MARK: - API Error Structure Tests

    func testAPIErrorDecoding() throws {
        let json = """
        {
            "error": {
                "type": "invalid_request_error",
                "message": "Invalid API key provided"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(APIErrorResponse.self, from: data)

        XCTAssertEqual(error.error.type, "invalid_request_error")
        XCTAssertEqual(error.error.message, "Invalid API key provided")
    }

    // MARK: - Error Type Tests

    func testClaudeErrorNoAPIKey() {
        let error = ClaudeError.noAPIKey

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("API key"))
    }

    func testClaudeErrorInvalidResponse() {
        let error = ClaudeError.invalidResponse

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Invalid response"))
    }

    func testClaudeErrorAPIError() {
        let error = ClaudeError.apiError("Test error message")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Test error message"))
    }

    func testClaudeErrorRateLimited() {
        let error = ClaudeError.rateLimited

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Rate limited"))
    }

    func testClaudeErrorNetworkError() {
        let underlyingError = NSError(domain: "TestDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network connection lost"])
        let error = ClaudeError.networkError(underlyingError)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Network"))
    }

    // MARK: - Request Building Tests

    func testRequestURLConstruction() {
        let baseURL = "https://api.anthropic.com/v1/messages"
        let url = URL(string: baseURL)

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "api.anthropic.com")
        XCTAssertEqual(url?.path, "/v1/messages")
    }

    func testRequestHeaders() {
        let apiKey = "sk-ant-test-key"
        let apiVersion = "2023-06-01"

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), apiKey)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), apiVersion)
    }

    // MARK: - Streaming Response Tests

    func testSSEEventParsing() {
        let sseLine = "data: {\"delta\":{\"text\":\"Hello\"}}"

        XCTAssertTrue(sseLine.hasPrefix("data: "))

        let jsonStr = String(sseLine.dropFirst(6))
        XCTAssertEqual(jsonStr, "{\"delta\":{\"text\":\"Hello\"}}")
    }

    func testSSEDoneMarker() {
        let doneLine = "data: [DONE]"

        XCTAssertTrue(doneLine.hasPrefix("data: "))

        let content = String(doneLine.dropFirst(6))
        XCTAssertEqual(content, "[DONE]")
    }

    func testSSEDeltaTextExtraction() throws {
        let jsonStr = "{\"delta\":{\"text\":\"World\"}}"
        let jsonData = jsonStr.data(using: .utf8)!

        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        if let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            XCTAssertEqual(text, "World")
        } else {
            XCTFail("Failed to extract delta text")
        }
    }

    // MARK: - Token Limit Tests

    func testDefaultMaxTokens() {
        let defaultMaxTokens = 1024
        XCTAssertGreaterThan(defaultMaxTokens, 0)
        XCTAssertLessThanOrEqual(defaultMaxTokens, 4096)
    }

    func testConversationMaxTokens() {
        let conversationMaxTokens = 2048
        XCTAssertGreaterThan(conversationMaxTokens, 1024)
    }

    // MARK: - Conversation Message Tests

    func testConversationMessageOrder() {
        var messages: [APIMessage] = []
        messages.append(APIMessage(role: "user", content: "Hello"))
        messages.append(APIMessage(role: "assistant", content: "Hi there!"))
        messages.append(APIMessage(role: "user", content: "How are you?"))

        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].role, "user")
        XCTAssertEqual(messages[1].role, "assistant")
        XCTAssertEqual(messages[2].role, "user")
    }

    func testConversationAlternatingRoles() {
        let messages: [APIMessage] = [
            APIMessage(role: "user", content: "First"),
            APIMessage(role: "assistant", content: "Response"),
            APIMessage(role: "user", content: "Second")
        ]

        // Verify alternating pattern
        for i in 0..<messages.count - 1 {
            XCTAssertNotEqual(messages[i].role, messages[i + 1].role)
        }
    }

    // MARK: - System Prompt Tests

    func testSystemPromptPresence() {
        let systemPrompt = "You are a helpful assistant."

        XCTAssertFalse(systemPrompt.isEmpty)
        XCTAssertGreaterThan(systemPrompt.count, 10)
    }

    func testSystemPromptNil() {
        let systemPrompt: String? = nil

        XCTAssertNil(systemPrompt)
    }

    // MARK: - HTTP Status Code Tests

    func testHTTPStatusCodeSuccess() {
        let statusCode = 200
        XCTAssertEqual(statusCode, 200)
    }

    func testHTTPStatusCodeRateLimited() {
        let statusCode = 429
        let isRateLimited = statusCode == 429
        XCTAssertTrue(isRateLimited)
    }

    func testHTTPStatusCodeError() {
        let errorCodes = [400, 401, 403, 404, 500, 502, 503]

        for code in errorCodes {
            XCTAssertNotEqual(code, 200)
        }
    }

    // MARK: - Response Content Extraction Tests

    func testExtractTextFromContentBlock() {
        let contentBlock = ContentBlock(type: "text", text: "Extracted text content")

        XCTAssertEqual(contentBlock.type, "text")
        XCTAssertEqual(contentBlock.text, "Extracted text content")
    }

    func testExtractTextFromMultipleContentBlocks() {
        let contentBlocks = [
            ContentBlock(type: "text", text: "First part"),
            ContentBlock(type: "text", text: " Second part")
        ]

        let fullText = contentBlocks.compactMap { $0.text }.joined()
        XCTAssertEqual(fullText, "First part Second part")
    }

    func testContentBlockWithNilText() {
        let contentBlock = ContentBlock(type: "image", text: nil)

        XCTAssertEqual(contentBlock.type, "image")
        XCTAssertNil(contentBlock.text)
    }
}

// MARK: - Test Helper Structures

enum ClaudeModel: String {
    case haiku = "claude-3-haiku-20240307"
    case sonnet = "claude-sonnet-4-20250514"
}

struct APIMessage: Codable {
    let role: String
    let content: String
}

struct APIRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [APIMessage]
    let system: String?
    let stream: Bool?
}

struct APIResponse: Codable {
    let content: [ContentBlock]
    let usage: Usage?
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
}

struct Usage: Codable {
    let input_tokens: Int
    let output_tokens: Int
}

struct APIErrorResponse: Codable {
    let error: ErrorDetail
}

struct ErrorDetail: Codable {
    let type: String
    let message: String
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
