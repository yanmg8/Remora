import Foundation
import Testing
@testable import RemoraApp
@testable import RemoraCore

@MainActor
struct FileTransferViewModelTests {
    @Test
    func uploadThenDownloadRoundTrip() async throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("remora-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let localFile = tempRoot.appendingPathComponent("hello.txt")
        try Data("hello-remora".utf8).write(to: localFile)

        let vm = FileTransferViewModel(
            sftpClient: MockSFTPClient(),
            localDirectoryURL: tempRoot,
            remoteDirectoryPath: "/",
            maxConcurrentTransfers: 2
        )

        vm.refreshLocalEntries()
        await vm.refreshRemoteEntries()

        guard let source = vm.localEntries.first(where: { $0.name == "hello.txt" }) else {
            Issue.record("Local fixture file not found")
            return
        }

        vm.enqueueUpload(localEntry: source)
        try await waitForSuccess(in: vm, transferName: "hello.txt", successCount: 1)

        await vm.refreshRemoteEntries()
        guard let remote = vm.remoteEntries.first(where: { $0.name == "hello.txt" }) else {
            Issue.record("Uploaded file missing on remote")
            return
        }

        try FileManager.default.removeItem(at: localFile)
        vm.refreshLocalEntries()

        vm.enqueueDownload(remoteEntry: remote)
        try await waitForSuccess(in: vm, transferName: "hello.txt", successCount: 2)

        let downloadedData = try Data(contentsOf: localFile)
        #expect(String(decoding: downloadedData, as: UTF8.self) == "hello-remora")
    }

    private func waitForSuccess(in vm: FileTransferViewModel, transferName: String, successCount: Int) async throws {
        for _ in 0 ..< 40 {
            let success = vm.transferQueue.filter { $0.name == transferName && $0.status == .success }.count
            if success >= successCount {
                return
            }
            if let failed = vm.transferQueue.first(where: { $0.name == transferName && $0.status == .failed }) {
                throw NSError(domain: "FileTransferViewModelTests", code: 1, userInfo: [NSLocalizedDescriptionKey: failed.message ?? "transfer failed"])
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw NSError(domain: "FileTransferViewModelTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "timeout waiting transfer success"])
    }
}
