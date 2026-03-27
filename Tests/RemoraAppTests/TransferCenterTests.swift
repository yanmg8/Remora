import Foundation
import Testing
@testable import RemoraApp

private actor TransferConcurrencyProbe {
    private var inFlight = 0
    private var maxInFlight = 0

    func begin() {
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
    }

    func end() {
        inFlight = max(0, inFlight - 1)
    }

    func observedMax() -> Int {
        maxInFlight
    }
}

private actor TransferBoolProbe {
    private var value = false

    func markTrue() {
        value = true
    }

    func currentValue() -> Bool {
        value
    }
}

struct TransferCenterTests {
    @Test
    func respectsMaxConcurrentTransfers() async throws {
        let center = TransferCenter(maxConcurrentTransfers: 2)
        let probe = TransferConcurrencyProbe()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 8 {
                group.addTask {
                    try? await center.acquireSlot()
                    await probe.begin()
                    try? await Task.sleep(for: .milliseconds(30))
                    await probe.end()
                    await center.releaseSlot()
                }
            }
        }

        let maxConcurrency = await probe.observedMax()
        #expect(maxConcurrency <= 2)
    }

    @Test
    func cancelledWaiterDoesNotBlockNextTransfer() async throws {
        let center = TransferCenter(maxConcurrentTransfers: 1)
        let acquiredProbe = TransferBoolProbe()

        try await center.acquireSlot()

        let cancelledWaiter = Task {
            do {
                try await center.acquireSlot()
                await center.releaseSlot()
                return false
            } catch is CancellationError {
                return true
            } catch {
                Issue.record("Unexpected waiter failure: \(error.localizedDescription)")
                return false
            }
        }

        try await Task.sleep(for: .milliseconds(30))
        cancelledWaiter.cancel()
        let waiterWasCancelled = await cancelledWaiter.value
        #expect(waiterWasCancelled)

        let nextWaiter = Task {
            try await center.acquireSlot()
            await acquiredProbe.markTrue()
            await center.releaseSlot()
        }

        try await Task.sleep(for: .milliseconds(30))
        await center.releaseSlot()

        for _ in 0 ..< 20 {
            if await acquiredProbe.currentValue() {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(await acquiredProbe.currentValue())
        try await nextWaiter.value
    }
}
