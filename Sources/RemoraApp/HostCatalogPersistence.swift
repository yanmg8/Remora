import CryptoKit
import Foundation
import RemoraCore

struct PersistedHostCatalog: Codable, Equatable {
    var hosts: [RemoraCore.Host]
    var templates: [HostSessionTemplate]
    var recentHostIDs: [UUID]
    var groups: [String]
}

struct EncryptedHostCatalogEnvelope: Codable, Equatable {
    var version: Int
    var algorithm: String
    var combined: String
}

enum HostCatalogPersistenceError: LocalizedError {
    case invalidKeyMaterial
    case invalidEncryptedBlob

    var errorDescription: String? {
        switch self {
        case .invalidKeyMaterial:
            return "Invalid key material for host catalog encryption."
        case .invalidEncryptedBlob:
            return "Encrypted host catalog payload is invalid."
        }
    }
}

actor HostCatalogPersistenceStore {
    private let credentialStore: CredentialStore
    private let baseDirectoryURL: URL
    private let storageFileURL: URL
    private let keyReference = "host-catalog-encryption-key-v1"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        credentialStore: CredentialStore = CredentialStore(),
        baseDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".remora/ssh", isDirectory: true)
    ) {
        self.credentialStore = credentialStore
        self.baseDirectoryURL = baseDirectoryURL
        self.storageFileURL = baseDirectoryURL.appendingPathComponent("connections.enc.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func load() async throws -> PersistedHostCatalog? {
        guard FileManager.default.fileExists(atPath: storageFileURL.path) else {
            return nil
        }

        let encryptedData = try Data(contentsOf: storageFileURL)
        let envelope = try decoder.decode(EncryptedHostCatalogEnvelope.self, from: encryptedData)
        let plainData = try await decrypt(envelope: envelope)
        return try decoder.decode(PersistedHostCatalog.self, from: plainData)
    }

    func save(_ snapshot: PersistedHostCatalog) async throws {
        try FileManager.default.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        let plainData = try encoder.encode(snapshot)
        let envelope = try await encrypt(plainData: plainData)
        let encryptedData = try encoder.encode(envelope)
        try encryptedData.write(to: storageFileURL, options: [.atomic])
    }

    private func encrypt(plainData: Data) async throws -> EncryptedHostCatalogEnvelope {
        let key = try await symmetricKey()
        let sealedBox = try AES.GCM.seal(plainData, using: key)
        guard let combined = sealedBox.combined else {
            throw HostCatalogPersistenceError.invalidEncryptedBlob
        }

        return EncryptedHostCatalogEnvelope(
            version: 1,
            algorithm: "AES.GCM",
            combined: combined.base64EncodedString()
        )
    }

    private func decrypt(envelope: EncryptedHostCatalogEnvelope) async throws -> Data {
        let key = try await symmetricKey()
        guard let combinedData = Data(base64Encoded: envelope.combined) else {
            throw HostCatalogPersistenceError.invalidEncryptedBlob
        }

        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    private func symmetricKey() async throws -> SymmetricKey {
        if let base64 = await credentialStore.secret(for: keyReference),
           let keyData = Data(base64Encoded: base64),
           keyData.count == 32
        {
            return SymmetricKey(data: keyData)
        }

        let generated = SymmetricKey(size: .bits256)
        let keyData = generated.withUnsafeBytes { Data($0) }
        guard keyData.count == 32 else {
            throw HostCatalogPersistenceError.invalidKeyMaterial
        }
        await credentialStore.setSecret(keyData.base64EncodedString(), for: keyReference)
        return generated
    }
}
