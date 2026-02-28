import Testing
@testable import RemoraApp

struct ByteSizeFormatterTests {
    @Test
    func bytesBelowOneKilobyteUseByteUnit() {
        #expect(ByteSizeFormatter.format(0) == "0B")
        #expect(ByteSizeFormatter.format(512) == "512B")
        #expect(ByteSizeFormatter.format(1023) == "1023B")
    }

    @Test
    func formatsKilobytesMegabytesAndGigabytes() {
        #expect(ByteSizeFormatter.format(1024) == "1KB")
        #expect(ByteSizeFormatter.format(1536) == "1.5KB")
        #expect(ByteSizeFormatter.format(1_048_576) == "1MB")
        #expect(ByteSizeFormatter.format(11 * 1_048_576) == "11MB")
        #expect(ByteSizeFormatter.format(5 * 1_073_741_824) == "5GB")
    }
}
