import Foundation

public final class RingByteBuffer: @unchecked Sendable {
    private var storage: [UInt8]
    private var head: Int = 0
    private var tail: Int = 0
    private var count: Int = 0
    private let lock = NSLock()

    public let capacity: Int

    public init(capacity: Int = 1 << 20) {
        self.capacity = max(capacity, 1)
        self.storage = Array(repeating: 0, count: self.capacity)
    }

    @discardableResult
    public func write(_ data: Data) -> Int {
        lock.lock()
        defer { lock.unlock() }

        var written = 0
        for byte in data {
            guard count < capacity else { break }
            storage[tail] = byte
            tail = (tail + 1) % capacity
            count += 1
            written += 1
        }
        return written
    }

    public func read(maxBytes: Int) -> Data {
        lock.lock()
        defer { lock.unlock() }

        guard maxBytes > 0, count > 0 else { return Data() }
        let toRead = min(maxBytes, count)

        var output = Data(capacity: toRead)
        for _ in 0 ..< toRead {
            output.append(storage[head])
            head = (head + 1) % capacity
            count -= 1
        }
        return output
    }

    public func drainAll() -> Data {
        read(maxBytes: capacity)
    }

    public var availableBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
