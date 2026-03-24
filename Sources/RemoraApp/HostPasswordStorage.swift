import Foundation
import RemoraCore

struct HostPasswordStorage {
    static func persist(
        authMethod: AuthenticationMethod,
        savePassword: Bool,
        newPasswordValue: String,
        oldPasswordReference: String?,
        hostID: UUID,
        credentialStore: CredentialStore
    ) async -> String? {
        guard authMethod == .password else {
            if let oldPasswordReference {
                await credentialStore.removeSecret(for: oldPasswordReference)
            }
            return nil
        }

        if savePassword {
            if !newPasswordValue.isEmpty {
                let key = oldPasswordReference ?? "host-password-\(hostID.uuidString)"
                await credentialStore.setSecret(newPasswordValue, for: key)
                return key
            }
            return oldPasswordReference
        }

        if let oldPasswordReference {
            await credentialStore.removeSecret(for: oldPasswordReference)
        }
        return nil
    }
}
