import Foundation

public actor MockSFTPClient: SFTPClientProtocol {
    private var files: [String: Data] = [
        "/README.txt": Data("Remora mock SFTP".utf8),
        "/logs/app.log": Data("service started".utf8),
    ]

    public init() {}

    public func list(path: String) async throws -> [RemoteFileEntry] {
        let normalized = normalize(path)
        let prefix = normalized == "/" ? "/" : normalized + "/"

        let names = Set(files.keys.compactMap { fullPath -> String? in
            guard fullPath.hasPrefix(prefix) else { return nil }
            let suffix = String(fullPath.dropFirst(prefix.count))
            guard !suffix.isEmpty else { return nil }
            return suffix.split(separator: "/").first.map(String.init)
        })

        return names.sorted().map { name in
            let fullPath = prefix + name
            let isDirectory = !files.keys.contains(fullPath)
            let size = files[fullPath].map { Int64($0.count) } ?? 0
            return RemoteFileEntry(name: name, path: fullPath, size: size, isDirectory: isDirectory)
        }
    }

    public func download(path: String) async throws -> Data {
        let key = normalize(path)
        return files[key] ?? Data()
    }

    public func upload(data: Data, to path: String) async throws {
        files[normalize(path)] = data
    }

    public func rename(from: String, to: String) async throws {
        let source = normalize(from)
        let destination = normalize(to)
        guard let value = files.removeValue(forKey: source) else { return }
        files[destination] = value
    }

    public func mkdir(path: String) async throws {
        // Mock storage infers directories from file prefixes.
        _ = normalize(path)
    }

    public func remove(path: String) async throws {
        files.removeValue(forKey: normalize(path))
    }

    private func normalize(_ path: String) -> String {
        guard path != "/" else { return path }
        let leading = path.hasPrefix("/") ? path : "/\(path)"
        return leading.replacingOccurrences(of: "//", with: "/")
    }
}
