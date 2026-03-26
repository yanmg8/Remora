import Foundation

enum TransferQueueAggregateStatus: Equatable {
    case idle
    case transferring
    case finishedWithIssues
    case completed
}

struct TransferQueueAggregateSnapshot: Equatable {
    var progress: Double
    var status: TransferQueueAggregateStatus

    static func resolve(
        items: [TransferItem],
        currentBatchID: Int?,
        runningFallbackProgress: Double
    ) -> TransferQueueAggregateSnapshot {
        guard let currentBatchID else {
            return TransferQueueAggregateSnapshot(progress: 0, status: .idle)
        }

        let batchItems = items.filter { $0.batchID == currentBatchID }
        guard !batchItems.isEmpty else {
            return TransferQueueAggregateSnapshot(progress: 0, status: .idle)
        }

        let hasActive = batchItems.contains { $0.status == .queued || $0.status == .running }
        let hasIssue = batchItems.contains { $0.status == .failed || $0.status == .skipped || $0.status == .stopped }

        let status: TransferQueueAggregateStatus
        if hasActive {
            status = .transferring
        } else if hasIssue {
            status = .finishedWithIssues
        } else {
            status = .completed
        }

        let aggregate = batchItems.reduce(Double(0)) { partial, item in
            partial + progressValue(for: item, runningFallbackProgress: runningFallbackProgress)
        }
        let progress = min(max(aggregate / Double(max(batchItems.count, 1)), 0), 1)
        return TransferQueueAggregateSnapshot(progress: progress, status: status)
    }

    private static func progressValue(
        for item: TransferItem,
        runningFallbackProgress: Double
    ) -> Double {
        switch item.status {
        case .success, .failed, .skipped, .stopped:
            return 1
        case .queued:
            return 0
        case .running:
            if let fraction = item.fractionCompleted {
                return min(max(fraction, 0), 1)
            }
            return min(max(runningFallbackProgress, 0), 1)
        }
    }
}

struct TransferQueueOverlayState: Equatable {
    var isExpanded = false
    var isPinned = false

    mutating func expand() {
        isExpanded = true
    }

    mutating func collapse() {
        isExpanded = false
    }

    mutating func togglePinned() {
        if isExpanded == false {
            isExpanded = true
        }
        isPinned.toggle()
    }

    mutating func handleOutsideClick() {
        guard isExpanded, isPinned == false else { return }
        isExpanded = false
    }

    mutating func handleTaskAvailabilityChanged(hasTasks: Bool) {
        guard hasTasks == false else { return }
        isExpanded = false
        isPinned = false
    }
}
