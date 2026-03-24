import Foundation
import Testing
@testable import RemoraApp
@testable import RemoraCore

struct HostPasswordStorageTests {
    @Test
    func savingPasswordCreatesReferenceAndPersistsSecret() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("remora-host-password-storage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CredentialStore(baseDirectoryURL: directory)
        let hostID = UUID()

        let reference = await HostPasswordStorage.persist(
            authMethod: .password,
            savePassword: true,
            newPasswordValue: "super-secret",
            oldPasswordReference: nil,
            hostID: hostID,
            credentialStore: store
        )

        #expect(reference == "host-password-\(hostID.uuidString)")
        let stored = await store.secret(for: reference ?? "")
        #expect(stored == "super-secret")
    }

    @Test
    func disablingSavedPasswordRemovesExistingSecret() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("remora-host-password-storage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CredentialStore(baseDirectoryURL: directory)
        await store.setSecret("super-secret", for: "pw-ref")

        let reference = await HostPasswordStorage.persist(
            authMethod: .password,
            savePassword: false,
            newPasswordValue: "",
            oldPasswordReference: "pw-ref",
            hostID: UUID(),
            credentialStore: store
        )

        #expect(reference == nil)
        let stored = await store.secret(for: "pw-ref")
        #expect(stored == nil)
    }

    @Test
    func switchingAwayFromPasswordAuthRemovesExistingSecret() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("remora-host-password-storage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CredentialStore(baseDirectoryURL: directory)
        await store.setSecret("super-secret", for: "pw-ref")

        let reference = await HostPasswordStorage.persist(
            authMethod: .agent,
            savePassword: true,
            newPasswordValue: "super-secret",
            oldPasswordReference: "pw-ref",
            hostID: UUID(),
            credentialStore: store
        )

        #expect(reference == nil)
        let stored = await store.secret(for: "pw-ref")
        #expect(stored == nil)
    }
}
