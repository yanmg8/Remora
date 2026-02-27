import Foundation
import Testing
@testable import RemoraCore

struct HostKeyStoreTests {
    @Test
    func firstSeenThenTrustedThenChanged() async {
        let store = HostKeyStore()

        let first = await store.validate(host: "example.com", fingerprint: "fp-1")
        #expect(first == .firstSeen)

        let second = await store.validate(host: "example.com", fingerprint: "fp-1")
        #expect(second == .trusted)

        let third = await store.validate(host: "example.com", fingerprint: "fp-2")
        #expect(third == .changed(old: "fp-1", new: "fp-2"))
    }
}
