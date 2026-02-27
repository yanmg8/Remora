import Foundation
import Testing
@testable import RemoraCore

struct RingByteBufferTests {
    @Test
    func writeAndReadRoundTrip() {
        let buffer = RingByteBuffer(capacity: 16)
        #expect(buffer.write(Data("hello".utf8)) == 5)
        let value = String(decoding: buffer.read(maxBytes: 5), as: UTF8.self)
        #expect(value == "hello")
        #expect(buffer.availableBytes == 0)
    }

    @Test
    func writeHonorsCapacity() {
        let buffer = RingByteBuffer(capacity: 8)
        let written = buffer.write(Data(repeating: 0x41, count: 32))
        #expect(written == 8)
    }
}
