import Foundation
import Testing
@testable import RemoraCore

struct MockSFTPClientTests {
    @Test
    func uploadRenameDownloadRemoveRoundTrip() async throws {
        let client = MockSFTPClient()

        try await client.upload(data: Data("hello".utf8), to: "/tmp/hello.txt")
        try await client.rename(from: "/tmp/hello.txt", to: "/tmp/world.txt")

        let payload = try await client.download(path: "/tmp/world.txt")
        #expect(String(decoding: payload, as: UTF8.self) == "hello")

        try await client.remove(path: "/tmp/world.txt")
        let list = try await client.list(path: "/tmp")
        #expect(list.first(where: { $0.name == "world.txt" }) == nil)
    }
}
