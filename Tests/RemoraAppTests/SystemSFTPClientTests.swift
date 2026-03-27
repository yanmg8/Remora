import Foundation
import Testing
@testable import RemoraCore

struct SystemSFTPClientTests {
    @Test
    func sshListFallbackAcceptsEmptyDirectoryResults() {
        #expect(SystemSFTPClient.shouldAcceptSSHListFallbackResult([]))

        let entries = [
            RemoteFileEntry(name: "README.txt", path: "/README.txt", size: 12, isDirectory: false),
        ]
        #expect(SystemSFTPClient.shouldAcceptSSHListFallbackResult(entries))
    }

    @Test
    func localFileProgressPollingEmitsIntermediateSnapshots() async throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("remora-system-progress-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fileURL = tempRoot.appendingPathComponent("download.bin")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        final class SnapshotRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var snapshots: [TransferProgressSnapshot] = []

            func append(_ snapshot: TransferProgressSnapshot) {
                lock.lock()
                snapshots.append(snapshot)
                lock.unlock()
            }

            func values() -> [TransferProgressSnapshot] {
                lock.lock()
                defer { lock.unlock() }
                return snapshots
            }
        }

        let recorder = SnapshotRecorder()
        let state = SystemSFTPClient.TransferProgressPollingState()

        async let monitor: Void = SystemSFTPClient.emitLocalFileProgress(
            fileURL: fileURL,
            expectedSize: 12,
            state: state,
            pollIntervalNanoseconds: 30_000_000,
            progress: { snapshot in
                recorder.append(snapshot)
            }
        )

        var handle = try FileHandle(forWritingTo: fileURL)
        try handle.write(contentsOf: Data(repeating: 0x01, count: 4))
        try handle.close()
        try await Task.sleep(nanoseconds: 160_000_000)
        handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(repeating: 0x02, count: 8))
        try handle.close()
        try await Task.sleep(nanoseconds: 160_000_000)
        await state.finish()
        _ = await monitor

        let snapshots = recorder.values()
        let observedFourBytes = snapshots.contains { snapshot in
            snapshot.bytesTransferred == 4 && snapshot.totalBytes == 12
        }
        let observedTwelveBytes = snapshots.contains { snapshot in
            snapshot.bytesTransferred == 12 && snapshot.totalBytes == 12
        }
        #expect(snapshots.count >= 2)
        #expect(observedFourBytes)
        #expect(observedTwelveBytes)
    }
}
