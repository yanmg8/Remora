import Foundation
import Testing
@testable import RemoraApp

struct TransferQueuePresentationStateTests {
    @Test
    func aggregateProgressTreatsStoppedAndFailedItemsAsCompletedBatchWork() {
        let items = [
            TransferItem(
                batchID: 3,
                direction: .download,
                name: "a.zip",
                sourcePath: "/a.zip",
                destinationPath: "/tmp/a.zip",
                status: .stopped,
                bytesTransferred: 10,
                totalBytes: 100
            ),
            TransferItem(
                batchID: 3,
                direction: .download,
                name: "b.zip",
                sourcePath: "/b.zip",
                destinationPath: "/tmp/b.zip",
                status: .failed,
                bytesTransferred: 20,
                totalBytes: 100
            ),
            TransferItem(
                batchID: 3,
                direction: .download,
                name: "c.zip",
                sourcePath: "/c.zip",
                destinationPath: "/tmp/c.zip",
                status: .success,
                bytesTransferred: 100,
                totalBytes: 100
            ),
        ]

        let snapshot = TransferQueueAggregateSnapshot.resolve(
            items: items,
            currentBatchID: 3,
            runningFallbackProgress: 0.1
        )

        #expect(snapshot.progress == 1)
        #expect(snapshot.status == TransferQueueAggregateStatus.finishedWithIssues)
    }

    @Test
    func aggregateProgressUsesOnlyCurrentBatch() {
        let items = [
            TransferItem(
                batchID: 1,
                direction: .download,
                name: "old.zip",
                sourcePath: "/old.zip",
                destinationPath: "/tmp/old.zip",
                status: .success,
                bytesTransferred: 100,
                totalBytes: 100
            ),
            TransferItem(
                batchID: 2,
                direction: .download,
                name: "new.zip",
                sourcePath: "/new.zip",
                destinationPath: "/tmp/new.zip",
                status: .queued,
                bytesTransferred: 0,
                totalBytes: 100
            ),
        ]

        let snapshot = TransferQueueAggregateSnapshot.resolve(
            items: items,
            currentBatchID: 2,
            runningFallbackProgress: 0.1
        )

        #expect(snapshot.progress == 0)
        #expect(snapshot.status == TransferQueueAggregateStatus.transferring)
    }

    @Test
    func outsideClickCollapsesOnlyWhenQueueIsNotPinned() {
        var state = TransferQueueOverlayState()
        state.expand()

        state.handleOutsideClick()

        #expect(state.isExpanded == false)
        #expect(state.isPinned == false)
    }

    @Test
    func outsideClickDoesNotCollapsePinnedQueue() {
        var state = TransferQueueOverlayState()
        state.expand()
        state.togglePinned()

        state.handleOutsideClick()

        #expect(state.isExpanded == true)
        #expect(state.isPinned == true)
    }

    @Test
    func clearingTasksResetsExpandedAndPinnedState() {
        var state = TransferQueueOverlayState()
        state.expand()
        state.togglePinned()

        state.handleTaskAvailabilityChanged(hasTasks: false)

        #expect(state.isExpanded == false)
        #expect(state.isPinned == false)
    }
}
