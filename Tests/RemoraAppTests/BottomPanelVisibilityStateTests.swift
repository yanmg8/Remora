import Testing
@testable import RemoraApp

struct BottomPanelVisibilityStateTests {
    @Test
    func collapsingTerminalOpensFileManagerWhenTerminalWasLastVisiblePanel() {
        var state = BottomPanelVisibilityState(terminal: true, fileManager: false)

        state.toggleTerminal(fileManagerAvailable: true)

        #expect(state.terminal == false)
        #expect(state.fileManager == true)
    }

    @Test
    func collapsingFileManagerOpensTerminalWhenFileManagerWasLastVisiblePanel() {
        var state = BottomPanelVisibilityState(terminal: false, fileManager: true)

        state.toggleFileManager(fileManagerAvailable: true)

        #expect(state.terminal == true)
        #expect(state.fileManager == false)
    }

    @Test
    func collapsingOnePanelKeepsTheOtherOpenWhenBothAreVisible() {
        var state = BottomPanelVisibilityState(terminal: true, fileManager: true)

        state.toggleTerminal(fileManagerAvailable: true)

        #expect(state.terminal == false)
        #expect(state.fileManager == true)
    }

    @Test
    func expandingClosedFileManagerAllowsBothPanelsToBeVisible() {
        var state = BottomPanelVisibilityState(terminal: true, fileManager: false)

        state.toggleFileManager(fileManagerAvailable: true)

        #expect(state.terminal == true)
        #expect(state.fileManager == true)
    }

    @Test
    func fileManagerUnavailabilityForcesTerminalToRemainVisible() {
        var state = BottomPanelVisibilityState(terminal: false, fileManager: true)

        state.normalize(fileManagerAvailable: false)

        #expect(state.terminal == true)
        #expect(state.fileManager == false)
    }
}
