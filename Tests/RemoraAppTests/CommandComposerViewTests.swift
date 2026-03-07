import AppKit
import Testing
@testable import RemoraApp

@MainActor
struct CommandComposerViewTests {
    @Test
    func commandComposerTextViewSubmitsOnInsertNewline() {
        let textView = CommandComposerTextView(frame: .zero)
        var submissions: [String] = []
        textView.onSubmit = { submissions.append($0) }
        textView.string = "echo hello"

        textView.doCommand(by: #selector(NSResponder.insertNewline(_:)))

        #expect(submissions == ["echo hello"])
        #expect(textView.string == "echo hello")
    }

    @Test
    func commandComposerTextViewInsertsLineBreakForInsertLineBreak() {
        let textView = CommandComposerTextView(frame: .zero)
        textView.string = "echo"
        textView.setSelectedRange(NSRange(location: 4, length: 0))

        textView.doCommand(by: #selector(NSResponder.insertLineBreak(_:)))

        #expect(textView.string == "echo\n")
        #expect(textView.selectedRange().location == 5)
    }
}
