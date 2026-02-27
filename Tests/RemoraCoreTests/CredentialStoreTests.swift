import Testing
@testable import RemoraCore

struct CredentialStoreTests {
    @Test
    func setGetRemoveSecret() async {
        let store = CredentialStore()

        await store.setSecret("secret-value", for: "api-token")
        let value = await store.secret(for: "api-token")
        #expect(value == "secret-value")

        await store.removeSecret(for: "api-token")
        let afterDelete = await store.secret(for: "api-token")
        #expect(afterDelete == nil)
    }
}
