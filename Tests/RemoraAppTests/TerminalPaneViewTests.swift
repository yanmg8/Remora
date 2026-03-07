import Testing
@testable import RemoraApp

struct TerminalPaneViewTests {
    @Test
    func visibleComposerUsesTopPlacementOrdering() {
        let layout = TerminalPaneLayout.resolve(
            isCommandComposerVisible: true,
            placement: .top,
            isPaneFocused: true
        )

        #expect(layout.sections == [.commandComposer, .terminal])
        #expect(layout.terminalAllowsKeyboardInput == false)
        #expect(layout.terminalPrefersInitialFocus == false)
    }

    @Test
    func visibleComposerUsesBottomPlacementOrdering() {
        let layout = TerminalPaneLayout.resolve(
            isCommandComposerVisible: true,
            placement: .bottom,
            isPaneFocused: true
        )

        #expect(layout.sections == [.terminal, .commandComposer])
        #expect(layout.terminalAllowsKeyboardInput == false)
        #expect(layout.terminalPrefersInitialFocus == false)
    }

    @Test
    func hiddenComposerRestoresTerminalOnlyInputMode() {
        let layout = TerminalPaneLayout.resolve(
            isCommandComposerVisible: false,
            placement: .bottom,
            isPaneFocused: true
        )

        #expect(layout.sections == [.terminal])
        #expect(layout.terminalAllowsKeyboardInput == true)
        #expect(layout.terminalPrefersInitialFocus == true)
    }
}
