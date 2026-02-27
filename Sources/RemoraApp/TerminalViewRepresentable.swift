import SwiftUI
import RemoraTerminal

struct TerminalViewRepresentable: NSViewRepresentable {
    @ObservedObject var runtime: TerminalRuntime

    func makeNSView(context: Context) -> TerminalView {
        let view = TerminalView(rows: 30, columns: 120)
        runtime.attach(view: view)
        return view
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        runtime.attach(view: nsView)
    }
}
