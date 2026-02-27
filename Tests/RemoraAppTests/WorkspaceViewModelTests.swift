import Testing
@testable import RemoraApp

@MainActor
struct WorkspaceViewModelTests {
    @Test
    func createAndCloseTab() {
        let workspace = WorkspaceViewModel()

        #expect(workspace.tabs.count == 1)
        let firstTabID = workspace.tabs[0].id

        workspace.createTab()
        #expect(workspace.tabs.count == 2)
        #expect(workspace.activeTabID != firstTabID)

        workspace.closeTab(firstTabID)
        #expect(workspace.tabs.count == 1)
    }

    @Test
    func splitActiveTabCreatesSecondPane() {
        let workspace = WorkspaceViewModel()
        let tab = workspace.tabs[0]

        workspace.splitActiveTab(orientation: .vertical)

        #expect(tab.panes.count == 2)
        #expect(tab.splitOrientation == .vertical)
        #expect(workspace.activePane != nil)
    }
}
