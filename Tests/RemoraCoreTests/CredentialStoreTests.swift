import Foundation
import Testing
@testable import RemoraCore

struct CredentialStoreTests {
    private func makeCredentialDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remora-credential-store-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(".remora/ssh", isDirectory: true)
    }

    @Test
    func setGetRemoveSecretWithoutPlaintextFile() async {
        let directory = makeCredentialDirectory()
        defer {
            let root = directory.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: root)
        }

        let store = CredentialStore(baseDirectoryURL: directory)

        await store.setSecret("secret-value", for: "api-token")
        let value = await store.secret(for: "api-token")
        #expect(value == "secret-value")
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("credentials.json").path))

        await store.removeSecret(for: "api-token")
        let afterDelete = await store.secret(for: "api-token")
        #expect(afterDelete == nil)
    }

    @Test
    func secretPersistsAcrossStoreInstances() async {
        let directory = makeCredentialDirectory()
        defer {
            let root = directory.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: root)
        }

        let first = CredentialStore(baseDirectoryURL: directory)
        await first.setSecret("db-pass", for: "db-ref")

        let second = CredentialStore(baseDirectoryURL: directory)
        let loaded = await second.secret(for: "db-ref")
        #expect(loaded == "db-pass")
    }

    @Test
    func secretUsesInMemoryCacheAfterFirstRead() async {
        let directory = makeCredentialDirectory()
        defer {
            let root = directory.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: root)
        }

        let first = CredentialStore(baseDirectoryURL: directory)
        await first.setSecret("cached-pass", for: "cache-ref")

        let second = CredentialStore(baseDirectoryURL: directory)
        let initialRead = await second.secret(for: "cache-ref")
        #expect(initialRead == "cached-pass")

        await first.removeSecret(for: "cache-ref")

        let cachedRead = await second.secret(for: "cache-ref")
        #expect(cachedRead == "cached-pass")
    }
}
