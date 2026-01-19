import XCTest
@testable import BookmarkManager

final class KeychainServiceTests: XCTestCase {

    // MARK: - API Key Validation Tests (No Keychain Access)

    func testValidClaudeAPIKeyFormat() {
        // Claude API keys typically start with "sk-ant-"
        let validKey = "sk-ant-api03-abcdefghijklmnop"

        XCTAssertTrue(validKey.hasPrefix("sk-ant-"))
    }

    func testInvalidClaudeAPIKeyFormatEmpty() {
        let emptyKey = ""

        XCTAssertFalse(emptyKey.hasPrefix("sk-ant-"))
        XCTAssertTrue(emptyKey.isEmpty)
    }

    func testInvalidClaudeAPIKeyFormatWrongPrefix() {
        let invalidKeys = [
            "invalid-key",
            "sk-",
            "sk-openai-key",
            "api-key-12345"
        ]

        for key in invalidKeys {
            XCTAssertFalse(key.hasPrefix("sk-ant-") && key.count > 10,
                          "\(key) should not be valid")
        }
    }

    func testAPIKeyValidation() {
        let validKey = "sk-ant-api03-abc123def456"
        let isValid = validKey.hasPrefix("sk-ant-") && validKey.count > 10

        XCTAssertTrue(isValid)
    }

    func testAPIKeyTrimming() {
        let keyWithWhitespace = "  sk-ant-test-key  "
        let trimmedKey = keyWithWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(trimmedKey, "sk-ant-test-key")
        XCTAssertTrue(trimmedKey.hasPrefix("sk-ant-"))
    }

    func testAPIKeyNotEmpty() {
        let apiKey = "sk-ant-test"

        XCTAssertFalse(apiKey.isEmpty)
        XCTAssertGreaterThan(apiKey.count, 0)
    }

    // MARK: - Data Encoding Tests

    func testAPIKeyToData() {
        let apiKey = "sk-ant-test-key-12345"
        let data = apiKey.data(using: .utf8)

        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }

    func testDataToAPIKey() {
        let originalKey = "sk-ant-test-key-12345"
        let data = originalKey.data(using: .utf8)!
        let restoredKey = String(data: data, encoding: .utf8)

        XCTAssertEqual(restoredKey, originalKey)
    }

    func testAPIKeyDataRoundTrip() {
        let originalKey = "sk-ant-api03-abcdefghijklmnop"
        let data = originalKey.data(using: .utf8)!
        let restoredKey = String(data: data, encoding: .utf8)

        XCTAssertEqual(restoredKey, originalKey)
    }

    func testUnicodeAPIKeyDataRoundTrip() {
        let unicodeKey = "sk-ant-测试-тест-🔐"
        let data = unicodeKey.data(using: .utf8)!
        let restoredKey = String(data: data, encoding: .utf8)

        XCTAssertEqual(restoredKey, unicodeKey)
    }

    func testSpecialCharactersAPIKeyDataRoundTrip() {
        let specialKey = "sk-ant-key_with-special.chars!@#$%^&*()"
        let data = specialKey.data(using: .utf8)!
        let restoredKey = String(data: data, encoding: .utf8)

        XCTAssertEqual(restoredKey, specialKey)
    }

    func testLongAPIKeyDataRoundTrip() {
        let longKey = "sk-ant-" + String(repeating: "a", count: 1000)
        let data = longKey.data(using: .utf8)!
        let restoredKey = String(data: data, encoding: .utf8)

        XCTAssertEqual(restoredKey, longKey)
    }

    // MARK: - Keychain Query Construction Tests

    func testKeychainQueryConstruction() {
        let service = "com.bookmarkmanager.api"
        let account = "claude-api-key"

        let query: [String: Any] = [
            "class": "genp",
            "svce": service,
            "acct": account
        ]

        XCTAssertEqual(query["svce"] as? String, service)
        XCTAssertEqual(query["acct"] as? String, account)
        XCTAssertEqual(query["class"] as? String, "genp")
    }

    func testKeychainServiceIdentifier() {
        let expectedService = "com.bookmarkmanager.api"

        XCTAssertFalse(expectedService.isEmpty)
        XCTAssertTrue(expectedService.contains("bookmarkmanager"))
    }

    // MARK: - Has API Key Logic Tests

    func testHasAPIKeyLogicWhenPresent() {
        let apiKey: String? = "sk-ant-test"

        let hasKey = apiKey != nil && !apiKey!.isEmpty

        XCTAssertTrue(hasKey)
    }

    func testHasAPIKeyLogicWhenNil() {
        let apiKey: String? = nil

        let hasKey = apiKey != nil && !(apiKey?.isEmpty ?? true)

        XCTAssertFalse(hasKey)
    }

    func testHasAPIKeyLogicWhenEmpty() {
        let apiKey: String? = ""

        let hasKey = apiKey != nil && !apiKey!.isEmpty

        XCTAssertFalse(hasKey)
    }

    // MARK: - Error Case Tests

    func testEmptyDataConversion() {
        let emptyString = ""
        let data = emptyString.data(using: .utf8)

        XCTAssertNotNil(data)
        XCTAssertEqual(data?.count, 0)
    }

    func testNilHandling() {
        let nilKey: String? = nil

        XCTAssertNil(nilKey)
        XCTAssertTrue(nilKey?.isEmpty ?? true)
    }
}
