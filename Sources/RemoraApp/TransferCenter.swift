import Foundation

actor TransferCenter {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private let maxConcurrentTransfers: Int
    private var activeTransfers = 0
    private var waiters: [Waiter] = []

    init(maxConcurrentTransfers: Int) {
        self.maxConcurrentTransfers = max(1, maxConcurrentTransfers)
    }

    func acquireSlot() async throws {
        if activeTransfers < maxConcurrentTransfers {
            activeTransfers += 1
            return
        }

        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: waiterID, continuation: continuation))
            }

            if Task.isCancelled {
                releaseSlot()
                throw CancellationError()
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: waiterID)
            }
        }
    }

    func releaseSlot() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.continuation.resume()
            return
        }

        activeTransfers = max(0, activeTransfers - 1)
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
