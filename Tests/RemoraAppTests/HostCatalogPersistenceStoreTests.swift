import Foundation
import Testing
import RemoraCore
@testable import RemoraApp

struct HostCatalogPersistenceStoreTests {
    @Test
    func saveAndLoadRoundTrip() async throws {
        let baseDirectory = makeTemporaryDirectory()
        defer {
            let root = baseDirectory.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: root)
        }

        let store = HostCatalogPersistenceStore(
            credentialStore: CredentialStore(),
            baseDirectoryURL: baseDirectory
        )

        let host = Host(
            name: "prod-api",
            address: "10.0.0.10",
            username: "deploy",
            group: "Production",
            tags: ["api"],
            auth: HostAuth(method: .agent)
        )

        let snapshot = PersistedHostCatalog(
            hosts: [host],
            templates: [
                HostSessionTemplate(hostID: host.id, name: "deploy")
            ],
            recentHostIDs: [host.id],
            groups: ["Production"]
        )

        try await store.save(snapshot)
        let loaded = try await store.load()

        #expect(loaded == snapshot)
    }

    @Test
    func savedPayloadIsEncryptedAndNotPlainJson() async throws {
        let baseDirectory = makeTemporaryDirectory()
        defer {
            let root = baseDirectory.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: root)
        }

        let store = HostCatalogPersistenceStore(
            credentialStore: CredentialStore(),
            baseDirectoryURL: baseDirectory
        )

        let host = Host(
            name: "internal-db",
            address: "192.168.30.120",
            username: "root",
            group: "LAN",
            tags: ["db"],
            auth: HostAuth(method: .password, passwordReference: "cred-1")
        )

        let snapshot = PersistedHostCatalog(
            hosts: [host],
            templates: [],
            recentHostIDs: [],
            groups: ["LAN"]
        )

        try await store.save(snapshot)

        let fileURL = baseDirectory.appendingPathComponent("connections.enc.json")
        let rawData = try Data(contentsOf: fileURL)
        let rawText = String(decoding: rawData, as: UTF8.self)

        #expect(!rawText.contains("internal-db"))
        #expect(!rawText.contains("192.168.30.120"))

        let envelope = try JSONDecoder().decode(EncryptedHostCatalogEnvelope.self, from: rawData)
        #expect(envelope.algorithm == "AES.GCM")
        #expect(!envelope.combined.isEmpty)
    }

    @Test
    func canDecryptUsingFileBackedKeyAfterKeychainSecretIsRemoved() async throws {
        let baseDirectory = makeTemporaryDirectory()
        defer {
            let root = baseDirectory.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: root)
        }

        let credentialStore = CredentialStore()
        let keyReference = "host-catalog-encryption-key-test-\(UUID().uuidString)"

        let firstStore = HostCatalogPersistenceStore(
            credentialStore: credentialStore,
            keyReference: keyReference,
            baseDirectoryURL: baseDirectory
        )

        let host = Host(
            name: "fallback-check",
            address: "172.16.0.8",
            username: "ops",
            group: "Ops",
            tags: [],
            auth: HostAuth(method: .agent)
        )
        let snapshot = PersistedHostCatalog(
            hosts: [host],
            templates: [],
            recentHostIDs: [],
            groups: ["Ops"]
        )

        try await firstStore.save(snapshot)
        let keyFileURL = baseDirectory.appendingPathComponent("catalog.key")
        #expect(FileManager.default.fileExists(atPath: keyFileURL.path))

        await credentialStore.removeSecret(for: keyReference)

        let secondStore = HostCatalogPersistenceStore(
            credentialStore: credentialStore,
            keyReference: keyReference,
            baseDirectoryURL: baseDirectory
        )
        let loaded = try await secondStore.load()
        #expect(loaded == snapshot)
        await credentialStore.removeSecret(for: keyReference)
    }

    private func makeTemporaryDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remora-host-catalog-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(".remora/ssh", isDirectory: true)
    }
}
