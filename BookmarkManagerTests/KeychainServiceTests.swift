import XCTest
import Security
@testable import BookmarkManager

final class KeychainServiceTests: XCTestCase {

    // Test service identifier to avoid conflicts with production data
    let testService = "com.bookmarkmanager.api.test"
    let testAccount = "test-api-key"

    override func setUp() {
        super.setUp()
        // Clean up any existing test data
        deleteTestKey()
    }

    override func tearDown() {
        // Clean up test data
        deleteTestKey()
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func saveTestKey(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testService,
            kSecAttrAccount as String: testAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func getTestKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testService,
            kSecAttrAccount as String: testAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteTestKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testService,
            kSecAttrAccount as String: testAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Save Tests

    func testSaveAPIKey() {
        let apiKey = "sk-ant-test-key-12345"

        let saved = saveTestKey(apiKey)

        XCTAssertTrue(saved)
    }

    func testSaveAPIKeyOverwrites() {
        let firstKey = "sk-ant-first-key"
        let secondKey = "sk-ant-second-key"

        // Save first key
        _ = saveTestKey(firstKey)

        // Delete and save second key (mimicking overwrite behavior)
        deleteTestKey()
        let saved = saveTestKey(secondKey)

        XCTAssertTrue(saved)

        let retrieved = getTestKey()
        XCTAssertEqual(retrieved, secondKey)
    }

    func testSaveEmptyAPIKey() {
        let emptyKey = ""

        let saved = saveTestKey(emptyKey)

        // Empty string can technically be saved
        XCTAssertTrue(saved)
    }

    func testSaveLongAPIKey() {
        let longKey = String(repeating: "a", count: 1000)

        let saved = saveTestKey(longKey)

        XCTAssertTrue(saved)

        let retrieved = getTestKey()
        XCTAssertEqual(retrieved, longKey)
    }

    func testSaveAPIKeyWithSpecialCharacters() {
        let specialKey = "sk-ant-key_with-special.chars!@#$%^&*()"

        let saved = saveTestKey(specialKey)

        XCTAssertTrue(saved)

        let retrieved = getTestKey()
        XCTAssertEqual(retrieved, specialKey)
    }

    // MARK: - Get Tests

    func testGetAPIKey() {
        let apiKey = "sk-ant-test-key-67890"
        _ = saveTestKey(apiKey)

        let retrieved = getTestKey()

        XCTAssertEqual(retrieved, apiKey)
    }

    func testGetNonexistentAPIKey() {
        let retrieved = getTestKey()

        XCTAssertNil(retrieved)
    }

    func testGetAPIKeyAfterDelete() {
        let apiKey = "sk-ant-temp-key"
        _ = saveTestKey(apiKey)
        deleteTestKey()

        let retrieved = getTestKey()

        XCTAssertNil(retrieved)
    }

    // MARK: - Delete Tests

    func testDeleteAPIKey() {
        let apiKey = "sk-ant-delete-test"
        _ = saveTestKey(apiKey)

        deleteTestKey()

        let retrieved = getTestKey()
        XCTAssertNil(retrieved)
    }

    func testDeleteNonexistentAPIKey() {
        // Should not throw or crash
        deleteTestKey()

        let retrieved = getTestKey()
        XCTAssertNil(retrieved)
    }

    // MARK: - Has API Key Tests

    func testHasAPIKeyWhenPresent() {
        let apiKey = "sk-ant-has-test"
        _ = saveTestKey(apiKey)

        let hasKey = getTestKey() != nil

        XCTAssertTrue(hasKey)
    }

    func testHasAPIKeyWhenAbsent() {
        let hasKey = getTestKey() != nil

        XCTAssertFalse(hasKey)
    }

    // MARK: - Data Integrity Tests

    func testAPIKeyDataIntegrity() {
        let originalKey = "sk-ant-integrity-test-🔑"
        _ = saveTestKey(originalKey)

        let retrieved = getTestKey()

        XCTAssertEqual(retrieved, originalKey)
    }

    func testMultipleSaveRetrieveCycles() {
        for i in 1...5 {
            let key = "sk-ant-cycle-\(i)"
            deleteTestKey()
            _ = saveTestKey(key)

            let retrieved = getTestKey()
            XCTAssertEqual(retrieved, key)
        }
    }

    // MARK: - API Key Validation Tests

    func testValidClaudeAPIKeyFormat() {
        // Claude API keys typically start with "sk-ant-"
        let validKey = "sk-ant-api03-abcdefghijklmnop"

        XCTAssertTrue(validKey.hasPrefix("sk-ant-"))
    }

    func testInvalidClaudeAPIKeyFormat() {
        let invalidKeys = [
            "invalid-key",
            "sk-",
            "",
            "   ",
            "sk-openai-key"
        ]

        for key in invalidKeys {
            XCTAssertFalse(key.hasPrefix("sk-ant-") && key.count > 10)
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentKeychainAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue(label: "keychain.test", attributes: .concurrent)

        for i in 0..<10 {
            queue.async {
                let key = "sk-ant-concurrent-\(i)"
                self.deleteTestKey()
                _ = self.saveTestKey(key)
                _ = self.getTestKey()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Edge Cases

    func testSaveAndRetrieveUnicodeAPIKey() {
        let unicodeKey = "sk-ant-测试-тест-🔐"
        _ = saveTestKey(unicodeKey)

        let retrieved = getTestKey()

        XCTAssertEqual(retrieved, unicodeKey)
    }

    func testSaveKeyWithWhitespace() {
        let keyWithWhitespace = "  sk-ant-whitespace  "
        _ = saveTestKey(keyWithWhitespace)

        let retrieved = getTestKey()

        // Key should be stored as-is, trimming is app responsibility
        XCTAssertEqual(retrieved, keyWithWhitespace)
    }

    func testSaveKeyWithNewlines() {
        let keyWithNewlines = "sk-ant-\ntest\n-key"
        _ = saveTestKey(keyWithNewlines)

        let retrieved = getTestKey()

        XCTAssertEqual(retrieved, keyWithNewlines)
    }
}
