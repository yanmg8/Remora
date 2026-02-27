import Foundation

public struct PerformanceSample: Sendable {
    public var frameDurationMS: Double
    public var inputLatencyMS: Double
    public var bytesPerSecond: Double
    public var timestamp: Date

    public init(
        frameDurationMS: Double,
        inputLatencyMS: Double,
        bytesPerSecond: Double,
        timestamp: Date = Date()
    ) {
        self.frameDurationMS = frameDurationMS
        self.inputLatencyMS = inputLatencyMS
        self.bytesPerSecond = bytesPerSecond
        self.timestamp = timestamp
    }
}

public actor PerformanceMetrics {
    private var samples: [PerformanceSample] = []
    private let maxSamples: Int

    public init(maxSamples: Int = 1024) {
        self.maxSamples = maxSamples
    }

    public func record(_ sample: PerformanceSample) {
        samples.append(sample)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    public func latest() -> PerformanceSample? {
        samples.last
    }

    public func summary() -> String {
        guard !samples.isEmpty else {
            return "No performance samples recorded."
        }

        let frameAvg = samples.map(\.frameDurationMS).reduce(0, +) / Double(samples.count)
        let inputAvg = samples.map(\.inputLatencyMS).reduce(0, +) / Double(samples.count)
        let throughputAvg = samples.map(\.bytesPerSecond).reduce(0, +) / Double(samples.count)

        return String(
            format: "samples=%d frame_avg=%.2fms input_avg=%.2fms throughput_avg=%.0fB/s",
            samples.count,
            frameAvg,
            inputAvg,
            throughputAvg
        )
    }

    public func logSummary(prefix: String = "[metrics]") {
        print("\(prefix) \(summary())")
    }
}
