import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let service = "com.bookmarkmanager.api"
    private let claudeAPIKeyAccount = "claude-api-key"

    private init() {}

    // MARK: - Claude API Key

    func saveClaudeAPIKey(_ apiKey: String) -> Bool {
        return save(key: claudeAPIKeyAccount, value: apiKey)
    }

    func getClaudeAPIKey() -> String? {
        return get(key: claudeAPIKeyAccount)
    }

    func deleteClaudeAPIKey() -> Bool {
        return delete(key: claudeAPIKeyAccount)
    }

    func hasClaudeAPIKey() -> Bool {
        return getClaudeAPIKey() != nil
    }

    // MARK: - Generic Keychain Operations

    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        _ = delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
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

    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
