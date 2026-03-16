import Foundation

@MainActor
final class RemoteLogViewerViewModel: ObservableObject {
    @Published var text: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isFollowing = true
    @Published private(set) var lineCount = FileTransferViewModel.defaultRemoteLogTailLineCount
    @Published var errorMessage: String?

    let path: String

    private let fileTransfer: FileTransferViewModel
    private let followRefreshInterval: Duration
    private var followTask: Task<Void, Never>?

    init(
        path: String,
        fileTransfer: FileTransferViewModel,
        followRefreshInterval: Duration = .seconds(1)
    ) {
        self.path = path
        self.fileTransfer = fileTransfer
        self.followRefreshInterval = followRefreshInterval
    }

    func load() async {
        await refresh(showLoading: true)
        updateFollowTask()
    }

    func refresh(showLoading: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if showLoading {
            isLoading = true
        }
        defer {
            isRefreshing = false
            if showLoading {
                isLoading = false
            }
        }

        do {
            let latest = try await fileTransfer.loadRemoteLogTail(path: path, lineCount: lineCount)
            if latest != text {
                text = latest
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setFollowing(_ enabled: Bool) {
        guard isFollowing != enabled else { return }
        isFollowing = enabled
        updateFollowTask()
    }

    func applyLineCount(_ value: Int) async {
        let clamped = min(max(value, 1), FileTransferViewModel.maxRemoteLogTailLineCount)
        guard clamped != lineCount else { return }
        lineCount = clamped
        await refresh(showLoading: false)
    }

    func stop() {
        followTask?.cancel()
        followTask = nil
    }

    private func updateFollowTask() {
        followTask?.cancel()
        followTask = nil

        guard isFollowing else { return }
        followTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: followRefreshInterval)
                guard !Task.isCancelled else { return }
                await self.refresh(showLoading: false)
            }
        }
    }
}
