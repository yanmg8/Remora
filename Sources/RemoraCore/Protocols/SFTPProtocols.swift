import Foundation

public protocol SFTPClientProtocol: Sendable {
    func list(path: String) async throws -> [RemoteFileEntry]
    func download(path: String) async throws -> Data
    func upload(data: Data, to path: String) async throws
    func rename(from: String, to: String) async throws
    func mkdir(path: String) async throws
    func remove(path: String) async throws
}

public struct RemoteFileEntry: Equatable, Sendable {
    public var name: String
    public var path: String
    public var size: Int64
    public var isDirectory: Bool
    public var modifiedAt: Date

    public init(
        name: String,
        path: String,
        size: Int64,
        isDirectory: Bool,
        modifiedAt: Date = Date()
    ) {
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.modifiedAt = modifiedAt
    }
}
