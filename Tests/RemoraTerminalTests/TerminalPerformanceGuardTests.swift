import Foundation
import Testing
@testable import RemoraTerminal

struct TerminalPerformanceGuardTests {
    @Test
    func parserMaintainsBaselineThroughput() {
        let parser = ANSIParser()
        let screen = ScreenBuffer(rows: 48, columns: 160)
        let payload = makePayload(lines: 10_000)
        let clock = ContinuousClock()

        let start = clock.now
        parser.parse(payload, into: screen)
        let elapsed = start.duration(to: clock.now)
        let elapsedMS = durationToMilliseconds(elapsed)
        let throughput = Double(payload.count) / max(elapsedMS / 1_000, 0.001)

        #expect(elapsedMS < 1_200, "ANSI parser latency regression: elapsed \(elapsedMS)ms")
        #expect(throughput > 500_000, "ANSI parser throughput regression: throughput \(throughput) B/s")
    }

    private func makePayload(lines: Int) -> Data {
        var payload = Data()
        for index in 0 ..< lines {
            payload.append(contentsOf: "\u{001B}[3\(index % 8)mline-\(index) benchmark payload\u{001B}[0m\r\n".utf8)
        }
        return payload
    }

    private func durationToMilliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
