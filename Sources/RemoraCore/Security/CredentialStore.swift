import Foundation
import Security

public actor CredentialStore {
    private struct CredentialFilePayload: Codable {
        var version: Int
        var values: [String: String]

        init(version: Int = 1, values: [String: String]) {
            self.version = version
            self.values = values
        }
    }

    private actor LegacyFileStore {
        private var loadedPaths: Set<String> = []
        private var valuesByPath: [String: [String: String]] = [:]
        private let encoder: JSONEncoder
        private let decoder: JSONDecoder

        init() {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            self.encoder = encoder
            self.decoder = JSONDecoder()
        }

        func value(for key: String, fileURL: URL) -> String? {
            loadIfNeeded(from: fileURL)
            return valuesByPath[fileURL.path]?[key]
        }

        func remove(for key: String, fileURL: URL) throws {
            loadIfNeeded(from: fileURL)
            var values = valuesByPath[fileURL.path] ?? [:]
            values.removeValue(forKey: key)
            try persist(values: values, to: fileURL)
            valuesByPath[fileURL.path] = values
        }

        private func loadIfNeeded(from fileURL: URL) {
            let path = fileURL.path
            guard !loadedPaths.contains(path) else { return }
            loadedPaths.insert(path)
            valuesByPath[path] = loadValuesFromFile(fileURL)
        }

        private func loadValuesFromFile(_ fileURL: URL) -> [String: String] {
            guard let data = try? Data(contentsOf: fileURL) else {
                return [:]
            }

            if let payload = try? decoder.decode(CredentialFilePayload.self, from: data) {
                return payload.values
            }

            if let legacyValues = try? decoder.decode([String: String].self, from: data) {
                return legacyValues
            }

            return [:]
        }

        private func persist(values: [String: String], to fileURL: URL) throws {
            if values.isEmpty {
                try? FileManager.default.removeItem(at: fileURL)
                return
            }

            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let payload = CredentialFilePayload(values: values)
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: [.atomic])
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        }
    }

    private static let sharedLegacyStore = LegacyFileStore()

    private let legacyFileURL: URL
    private let serviceName: String
    private var inMemoryStorage: [String: String] = [:]

    public init(
        baseDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".remora/ssh", isDirectory: true),
        credentialsFilename: String = "credentials.json"
    ) {
        self.legacyFileURL = baseDirectoryURL.appendingPathComponent(credentialsFilename)
        self.serviceName = Self.makeServiceName(baseDirectoryURL: baseDirectoryURL, credentialsFilename: credentialsFilename)
    }

    public func setSecret(_ value: String, for key: String) async {
        inMemoryStorage[key] = value
        do {
            try Self.upsertKeychainValue(value, service: serviceName, account: key)
            try? await Self.sharedLegacyStore.remove(for: key, fileURL: legacyFileURL)
        } catch {
            return
        }
    }

    public func secret(for key: String) async -> String? {
        if let value = inMemoryStorage[key] {
            return value
        }

        if let keychainValue = try? Self.readKeychainValue(service: serviceName, account: key) {
            inMemoryStorage[key] = keychainValue
            return keychainValue
        }

        guard let legacyValue = await Self.sharedLegacyStore.value(for: key, fileURL: legacyFileURL) else {
            return nil
        }

        inMemoryStorage[key] = legacyValue
        do {
            try Self.upsertKeychainValue(legacyValue, service: serviceName, account: key)
            try? await Self.sharedLegacyStore.remove(for: key, fileURL: legacyFileURL)
        } catch {
            // Keep serving the migrated value from memory for this session.
        }
        return legacyValue
    }

    public func removeSecret(for key: String) async {
        inMemoryStorage.removeValue(forKey: key)
        _ = try? Self.deleteKeychainValue(service: serviceName, account: key)
        _ = try? await Self.sharedLegacyStore.remove(for: key, fileURL: legacyFileURL)
    }

    private static func makeServiceName(baseDirectoryURL: URL, credentialsFilename: String) -> String {
        let namespace = "\(baseDirectoryURL.standardizedFileURL.path)|\(credentialsFilename)"
        return "io.lighting-tech.remora.credentials.\(stableHash(namespace))"
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    private static func keychainQuery(service: String, account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
    }

    private static func upsertKeychainValue(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        var query = keychainQuery(service: service, account: account)
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock

        let updateAttributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
            }
        case errSecItemNotFound:
            query[kSecValueData] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private static func readKeychainValue(service: String, account: String) throws -> String? {
        var query = keychainQuery(service: service, account: account)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private static func deleteKeychainValue(service: String, account: String) throws {
        let status = SecItemDelete(keychainQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
