import Foundation
import RemoraCore
import RemoraTerminal

enum ConnectionMode: String, CaseIterable, Identifiable, Sendable {
    case mock = "Mock"
    case ssh = "SSH"

    var id: String { rawValue }
}

struct TerminalConnectConfig: Sendable {
    var mode: ConnectionMode
    var hostAddress: String
    var hostPort: Int
    var username: String
    var privateKeyPath: String?
}

@MainActor
final class TerminalRuntime: ObservableObject {
    @Published var connectionState: String = "Idle"
    @Published var connectionMode: ConnectionMode = .mock

    private let mockSessionManager = SessionManager(sshClientFactory: { MockSSHClient() })
    private let sshSessionManager = SessionManager(sshClientFactory: { SystemSSHClient() })

    private weak var terminalView: TerminalView?
    private var activeSessionManager: SessionManager?
    private var sessionID: UUID?
    private var streamTask: Task<Void, Never>?
    private var isPaneActive = true

    func attach(view: TerminalView) {
        terminalView = view
        view.isDisplayActive = isPaneActive
        view.onInput = { [weak self] data in
            Task {
                await self?.sendInput(data)
            }
        }
    }

    func setPaneActive(_ isActive: Bool) {
        isPaneActive = isActive
        terminalView?.isDisplayActive = isActive
    }

    func connectMock() {
        connect(
            using: TerminalConnectConfig(
                mode: .mock,
                hostAddress: "127.0.0.1",
                hostPort: 22,
                username: "remora",
                privateKeyPath: nil
            )
        )
    }

    func connectSSH(address: String, port: Int, username: String, privateKeyPath: String?) {
        connect(
            using: TerminalConnectConfig(
                mode: .ssh,
                hostAddress: address,
                hostPort: port,
                username: username,
                privateKeyPath: privateKeyPath
            )
        )
    }

    func connect(using config: TerminalConnectConfig) {
        guard sessionID == nil else { return }
        connectionMode = config.mode
        connectionState = "Connecting"

        guard let host = buildHostConfiguration(config: config) else {
            connectionState = "配置错误：请检查主机、端口、用户名"
            return
        }

        let manager = config.mode == .mock ? mockSessionManager : sshSessionManager
        activeSessionManager = manager

        Task {
            do {
                let descriptor = try await manager.startSession(
                    for: host,
                    pty: .init(columns: 120, rows: 30)
                )
                sessionID = descriptor.id
                connectionState = "Connected (\(config.mode.rawValue))"
                bindOutput(for: descriptor.id, manager: manager)
            } catch {
                connectionState = "Failed: \(error.localizedDescription)"
            }
        }
    }

    func disconnect() {
        guard let sessionID, let manager = activeSessionManager else { return }

        Task {
            await manager.stopSession(id: sessionID)
            await MainActor.run {
                self.sessionID = nil
                self.activeSessionManager = nil
                self.connectionState = "Disconnected"
                self.streamTask?.cancel()
                self.streamTask = nil
            }
        }
    }

    private func bindOutput(for id: UUID, manager: SessionManager) {
        streamTask?.cancel()
        streamTask = Task {
            let stream = await manager.sessionOutputStream(sessionID: id)
            for await data in stream {
                await MainActor.run {
                    terminalView?.feed(data: data)
                }
            }
        }
    }

    private func sendInput(_ data: Data) async {
        guard let sessionID, let manager = activeSessionManager else { return }

        do {
            try await manager.write(data, to: sessionID)
        } catch {
            await MainActor.run {
                connectionState = "Write failed: \(error.localizedDescription)"
            }
        }
    }

    private func buildHostConfiguration(config: TerminalConnectConfig) -> RemoraCore.Host? {
        let trimmedHost = config.hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = config.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, !trimmedUser.isEmpty else { return nil }
        guard config.hostPort > 0, config.hostPort < 65536 else { return nil }

        let keyPath = config.privateKeyPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let auth: HostAuth = {
            if let keyPath, !keyPath.isEmpty {
                return HostAuth(method: .privateKey, keyReference: keyPath)
            }
            return HostAuth(method: .agent)
        }()

        return RemoraCore.Host(
            name: trimmedHost,
            address: trimmedHost,
            port: config.hostPort,
            username: trimmedUser,
            auth: auth
        )
    }
}
