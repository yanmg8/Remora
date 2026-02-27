import Foundation
import Testing
@testable import RemoraTerminal

struct ScrollbackStoreTests {
    @Test
    func createsMultipleSegments() {
        let store = ScrollbackStore(segmentSize: 2)
        var line = TerminalLine(columns: 2)

        line[0] = TerminalCell(character: "a", attributes: .default)
        store.append(line)
        store.append(line)
        store.append(line)

        #expect(store.segmentCount() == 2)
        #expect(store.lineCount() == 3)
    }
}
