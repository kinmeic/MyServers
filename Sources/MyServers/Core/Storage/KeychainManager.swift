import Foundation
import Security

/// Secure storage for passwords and private key passphrases.
enum KeychainManager {
    static func savePassword(_ password: String, for serverId: UUID) {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serverId.uuidString,
            kSecAttrService as String: "com.myservers.password",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func getPassword(for serverId: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serverId.uuidString,
            kSecAttrService as String: "com.myservers.password",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return nil }

        return password
    }

    static func deletePassword(for serverId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serverId.uuidString,
            kSecAttrService as String: "com.myservers.password",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
