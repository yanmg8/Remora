import SwiftUI
import RemoraTerminal

@MainActor
struct TerminalViewRepresentable: NSViewRepresentable {
    @ObservedObject var runtime: TerminalRuntime
    var allowsKeyboardInput: Bool = true
    var prefersInitialFocus: Bool = true
    var onFocus: () -> Void = {}

    func makeNSView(context: Context) -> TerminalView {
        let view = TerminalView(rows: 30, columns: 120)
        applyTerminalSettings(to: view)
        view.onFocus = onFocus
        view.allowsKeyboardInput = allowsKeyboardInput
        view.prefersInitialFocusOnWindowAttach = prefersInitialFocus
        view.onResize = { columns, rows in
            runtime.resize(columns: columns, rows: rows)
        }
        runtime.attach(view: view)
        return view
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        applyTerminalSettings(to: nsView)
        nsView.onFocus = onFocus
        nsView.allowsKeyboardInput = allowsKeyboardInput
        nsView.prefersInitialFocusOnWindowAttach = prefersInitialFocus
        nsView.onResize = { columns, rows in
            runtime.resize(columns: columns, rows: rows)
        }
        runtime.attach(view: nsView)
        if prefersInitialFocus,
           allowsKeyboardInput,
           nsView.window?.firstResponder as AnyObject? !== nsView
        {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    @MainActor
    private func applyTerminalSettings(to view: TerminalView) {
        view.wordSeparators = CharacterSet(charactersIn: AppSettings.resolvedTerminalWordSeparators())
        view.scrollSensitivity = AppSettings.resolvedTerminalScrollSensitivity()
        view.fastScrollSensitivity = AppSettings.resolvedTerminalFastScrollSensitivity()
        view.scrollOnUserInput = AppSettings.resolvedTerminalScrollOnUserInput()
    }
}
