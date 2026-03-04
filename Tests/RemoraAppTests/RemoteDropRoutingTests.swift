import Foundation
import Testing
import RemoraCore
@testable import RemoraApp

struct RemoteDropRoutingTests {
    @Test
    func resolvesDirectoryDropToDirectoryPath() {
        let directory = RemoteFileEntry(
            name: "logs",
            path: "/var/log",
            size: 0,
            isDirectory: true
        )

        let target = RemoteDropRouting.resolveUploadTargetDirectory(
            dropTargetEntry: directory,
            currentRemoteDirectory: "/home/app"
        )
        #expect(target == "/var/log")
    }

    @Test
    func resolvesFileDropToCurrentDirectory() {
        let file = RemoteFileEntry(
            name: "app.log",
            path: "/var/log/app.log",
            size: 1024,
            isDirectory: false
        )

        let target = RemoteDropRouting.resolveUploadTargetDirectory(
            dropTargetEntry: file,
            currentRemoteDirectory: "/home/app"
        )
        #expect(target == "/home/app")
    }

    @Test
    func resolvesEmptyAreaDropToCurrentDirectory() {
        let target = RemoteDropRouting.resolveUploadTargetDirectory(
            dropTargetEntry: nil,
            currentRemoteDirectory: "/home/app"
        )
        #expect(target == "/home/app")
    }

    @Test
    func acceptsOnlyLocalFileURLsAndDeduplicates() {
        let first = URL(fileURLWithPath: "/tmp/a.txt")
        let duplicate = URL(fileURLWithPath: "/tmp/a.txt")
        let second = URL(fileURLWithPath: "/tmp/b")
        let remoteLike = URL(string: "https://example.com/a.txt")!

        let accepted = RemoteDropRouting.acceptedLocalDropURLs([first, duplicate, second, remoteLike])
        #expect(accepted == [first.standardizedFileURL, second.standardizedFileURL])
    }
}
