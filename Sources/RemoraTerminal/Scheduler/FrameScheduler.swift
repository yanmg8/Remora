import Foundation

public final class FrameScheduler: @unchecked Sendable {
    private let queue: DispatchQueue
    private let frameIntervalMS: Int
    private var timer: DispatchSourceTimer?
    private let callback: @Sendable () -> Void

    public init(frameIntervalMS: Int = 16, queue: DispatchQueue = DispatchQueue(label: "remora.terminal.frame"), callback: @escaping @Sendable () -> Void) {
        self.frameIntervalMS = frameIntervalMS
        self.queue = queue
        self.callback = callback
    }

    public func start() {
        guard timer == nil else { return }

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(frameIntervalMS), leeway: .milliseconds(2))
        source.setEventHandler(handler: callback)
        source.resume()
        timer = source
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        stop()
    }
}
