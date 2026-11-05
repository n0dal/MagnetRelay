import Foundation
import Security

enum KeychainService {
    private static let service = "com.magnetrelay.server"
    private static let account = "password"

    @discardableResult
    static func setPassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }

        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        var add = match
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        return write(update: { SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary) },
                     delete: { SecItemDelete(match as CFDictionary) },
                     add: { SecItemAdd(add as CFDictionary, nil) })
    }

    /// Update in place; add if missing. Any other update failure (e.g. the item was written under a
    /// different code-signing identity) falls back to delete-then-add.
    static func write(update: () -> OSStatus, delete: () -> OSStatus, add: () -> OSStatus) -> Bool {
        let status = update()
        if status == errSecSuccess { return true }
        if status != errSecItemNotFound {
            let deleted = delete()
            guard deleted == errSecSuccess || deleted == errSecItemNotFound else { return false }
        }
        return add() == errSecSuccess
    }

    static func getPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }
}
