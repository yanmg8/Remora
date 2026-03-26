import Testing
@testable import RemoraApp

struct FileManagerContextMenuTests {
    @Test
    func downloadActionStaysEnabledForDirectories() {
        #expect(FileManagerContextMenuPolicy.isDownloadDisabled(isDirectory: false) == false)
        #expect(FileManagerContextMenuPolicy.isDownloadDisabled(isDirectory: true) == false)
    }
}
