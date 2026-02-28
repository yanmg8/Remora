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

    private actor SharedFileStore {
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

        func set(_ value: String, for key: String, fileURL: URL) throws {
            loadIfNeeded(from: fileURL)
            var values = valuesByPath[fileURL.path] ?? [:]
            values[key] = value
            try persist(values: values, to: fileURL)
            valuesByPath[fileURL.path] = values
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

    private static let sharedStore = SharedFileStore()
    private let baseDirectoryURL: URL
    private let credentialsFileURL: URL
    private var inMemoryStorage: [String: String] = [:]

    public init(
        baseDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".remora/ssh", isDirectory: true),
        credentialsFilename: String = "credentials.json"
    ) {
        self.baseDirectoryURL = baseDirectoryURL
        self.credentialsFileURL = baseDirectoryURL.appendingPathComponent(credentialsFilename)
    }

    public func setSecret(_ value: String, for key: String) async {
        inMemoryStorage[key] = value
        do {
            try await Self.sharedStore.set(value, for: key, fileURL: credentialsFileURL)
        } catch {
            return
        }
    }

    public func secret(for key: String) async -> String? {
        if let value = inMemoryStorage[key] {
            return value
        }

        if let cached = await Self.sharedStore.value(for: key, fileURL: credentialsFileURL) {
            inMemoryStorage[key] = cached
            return cached
        }
        return nil
    }

    public func removeSecret(for key: String) async {
        inMemoryStorage.removeValue(forKey: key)
        _ = try? await Self.sharedStore.remove(for: key, fileURL: credentialsFileURL)
    }
}
