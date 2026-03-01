import AppKit
import Testing
@testable import RemoraApp

struct RemoteListSelectionTests {
    @Test
    func plainClickSelectsSinglePathAndResetsAnchor() {
        let ordered = ["/a", "/b", "/c"]
        let result = RemoteListSelection.applyClick(
            currentSelection: ["/a", "/b"],
            anchorPath: "/a",
            orderedPaths: ordered,
            clickedPath: "/c",
            modifiers: []
        )

        #expect(result.selectedPaths == ["/c"])
        #expect(result.anchorPath == "/c")
    }

    @Test
    func commandClickTogglesPathWithoutCheckboxes() {
        let ordered = ["/a", "/b", "/c"]
        let result = RemoteListSelection.applyClick(
            currentSelection: ["/a"],
            anchorPath: "/a",
            orderedPaths: ordered,
            clickedPath: "/b",
            modifiers: [.command]
        )

        #expect(result.selectedPaths == ["/a", "/b"])
        #expect(result.anchorPath == "/b")
    }

    @Test
    func shiftClickSelectsContiguousRangeFromAnchor() {
        let ordered = ["/a", "/b", "/c", "/d", "/e"]
        let result = RemoteListSelection.applyClick(
            currentSelection: ["/b"],
            anchorPath: "/b",
            orderedPaths: ordered,
            clickedPath: "/e",
            modifiers: [.shift]
        )

        #expect(result.selectedPaths == ["/b", "/c", "/d", "/e"])
        #expect(result.anchorPath == "/b")
    }
}
