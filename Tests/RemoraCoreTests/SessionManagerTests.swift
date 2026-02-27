import Foundation
import Testing
@testable import RemoraCore

struct SessionManagerTests {
    @Test
    func startWriteAndStopSession() async throws {
        let manager = SessionManager(sshClientFactory: { MockSSHClient() })
        let host = Host(
            name: "demo",
            address: "127.0.0.1",
            username: "tester",
            auth: HostAuth(method: .agent)
        )

        let descriptor = try await manager.startSession(for: host, pty: .init(columns: 100, rows: 30))
        let sessions = await manager.activeSessions()
        #expect(sessions.count == 1)
        #expect(sessions.first?.id == descriptor.id)

        try await manager.write(Data("whoami\r".utf8), to: descriptor.id)

        await manager.stopSession(id: descriptor.id)
        let empty = await manager.activeSessions()
        #expect(empty.isEmpty)
    }
}
