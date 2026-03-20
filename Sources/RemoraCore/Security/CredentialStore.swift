import Foundation

public actor CredentialStore {
    private struct CredentialFilePayload: Codable {
        var version: Int
        var values: [String: String]

        init(version: Int = 1, values: [String: String]) {
            self.version = version
            self.values = values
        }
    }

    private let fileStore: RemoraJSONFileStore<CredentialFilePayload>
    private var inMemoryStorage: [String: String] = [:]

    public init(
        baseDirectoryURL: URL = RemoraConfigPaths.rootDirectoryURL(),
        credentialsFilename: String = RemoraConfigFile.credentials.rawValue
    ) {
        let fileURL = baseDirectoryURL.appendingPathComponent(credentialsFilename, isDirectory: false)
        self.fileStore = RemoraJSONFileStore(fileURL: fileURL, outputFormatting: [.sortedKeys])
    }

    public func setSecret(_ value: String, for key: String) async {
        inMemoryStorage[key] = value
        try? persistCurrentState()
    }

    public func secret(for key: String) async -> String? {
        if let value = inMemoryStorage[key] {
            return value
        }

        guard let payload = try? fileStore.load(),
              let value = payload.values[key]
        else {
            return nil
        }

        inMemoryStorage[key] = value
        return value
    }

    public func removeSecret(for key: String) async {
        inMemoryStorage.removeValue(forKey: key)
        try? persistCurrentState(removeOnlyKey: key)
    }

    private func persistCurrentState(removeOnlyKey removedKey: String? = nil) throws {
        var values = (try fileStore.load())?.values ?? [:]
        values.merge(inMemoryStorage) { _, new in new }

        if let removedKey {
            values.removeValue(forKey: removedKey)
        }

        if values.isEmpty {
            try fileStore.remove()
        } else {
            try fileStore.save(CredentialFilePayload(values: values))
        }
    }
}
