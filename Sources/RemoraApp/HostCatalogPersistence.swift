import Foundation
import RemoraCore

struct PersistedHostCatalog: Codable, Equatable {
    var hosts: [RemoraCore.Host]
    var templates: [HostSessionTemplate]
    var recentHostIDs: [UUID]
    var groups: [String]
}

actor HostCatalogPersistenceStore {
    private let storageFileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseDirectoryURL: URL = RemoraConfigPaths.rootDirectoryURL()
    ) {
        self.storageFileURL = baseDirectoryURL.appendingPathComponent(RemoraConfigFile.connections.rawValue, isDirectory: false)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func load() async throws -> PersistedHostCatalog? {
        guard FileManager.default.fileExists(atPath: storageFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: storageFileURL)
        return try decoder.decode(PersistedHostCatalog.self, from: data)
    }

    func fileExists() -> Bool {
        FileManager.default.fileExists(atPath: storageFileURL.path)
    }

    func save(_ snapshot: PersistedHostCatalog) async throws {
        try FileManager.default.createDirectory(
            at: storageFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: storageFileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: storageFileURL.path
        )
    }
}
