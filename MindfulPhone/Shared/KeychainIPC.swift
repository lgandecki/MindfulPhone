import Foundation
import Security

/// Lightweight Keychain read/write/delete for inter-process communication
/// between the main app and extensions via the shared App Group access group.
enum KeychainIPC {
    private static let accessGroup = AppGroupConstants.suiteName
    private static let service = "net.lgandecki.mindfulphone.ipc"

    /// Save a string value to the shared Keychain. Deletes existing entry first.
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        let data = Data(value.utf8)
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("[KeychainIPC] save failed for key=%@ status=%d", key, status)
        }
        return status == errSecSuccess
    }

    /// Read a string value from the shared Keychain.
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a key from the shared Keychain.
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
