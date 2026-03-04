import Foundation
import RemoraCore

enum RemoteDropRouting {
    static func acceptedLocalDropURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var accepted: [URL] = []
        accepted.reserveCapacity(urls.count)

        for url in urls where url.isFileURL {
            let normalized = url.standardizedFileURL
            let key = normalized.path
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            accepted.append(normalized)
        }
        return accepted
    }

    static func resolveUploadTargetDirectory(
        dropTargetEntry: RemoteFileEntry?,
        currentRemoteDirectory: String
    ) -> String {
        guard let dropTargetEntry, dropTargetEntry.isDirectory else {
            return currentRemoteDirectory
        }
        return dropTargetEntry.path
    }
}
