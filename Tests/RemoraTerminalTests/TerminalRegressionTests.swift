import Foundation
import Testing
@testable import RemoraTerminal

struct TerminalRegressionTests {
    @Test
    func clearScreenResetsVisibleBuffer() {
        let parser = ANSIParser()
        let screen = ScreenBuffer(rows: 3, columns: 8)

        parser.parse(Data("abc\r\ndef\r\n".utf8), into: screen)
        parser.parse(Data("\u{001B}[2J\u{001B}[H".utf8), into: screen)

        let line0 = screen.line(at: 0)
        #expect(line0[0].character == " ")
        #expect(screen.cursorRow == 0)
        #expect(screen.cursorColumn == 0)
    }

    @Test
    func scrollbackAppendsOverflowLines() {
        let parser = ANSIParser()
        let screen = ScreenBuffer(rows: 2, columns: 8, scrollbackSegmentSize: 1)

        parser.parse(Data("row1\r\nrow2\r\nrow3\r\n".utf8), into: screen)

        #expect(screen.scrollback.lineCount() >= 1)
        #expect(screen.scrollback.segmentCount() >= 1)
    }
}
