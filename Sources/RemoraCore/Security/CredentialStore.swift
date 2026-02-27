import Foundation
import Security

public actor CredentialStore {
    private let service = "io.lighting-tech.remora.credentials"
    private var inMemoryStorage: [String: String] = [:]

    public init() {}

    public func setSecret(_ value: String, for key: String) {
        inMemoryStorage[key] = value
        _ = saveToKeychain(value, for: key)
    }

    public func secret(for key: String) -> String? {
        if let value = inMemoryStorage[key] {
            return value
        }

        if let value = readFromKeychain(for: key) {
            inMemoryStorage[key] = value
            return value
        }
        return nil
    }

    public func removeSecret(for key: String) {
        inMemoryStorage.removeValue(forKey: key)
        deleteFromKeychain(for: key)
    }

    @discardableResult
    private func saveToKeychain(_ value: String, for key: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)

        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }

    private func readFromKeychain(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
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

    private func deleteFromKeychain(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
