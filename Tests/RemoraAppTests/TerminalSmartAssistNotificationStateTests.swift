import Testing
@testable import RemoraApp

@Suite
struct TerminalSmartAssistNotificationStateTests {
    @Test
    func visibleSmartAssistAppearsOnlyWhenAIIsEnabledAndDrawerIsHidden() {
        let smartAssist = TerminalAISmartAssist(
            kind: .commandNotFound,
            title: "Command not found",
            prompt: "Explain why this command was not found"
        )
        let state = TerminalSmartAssistNotificationState()

        #expect(state.visibleSmartAssist(aiEnabled: true, isAIAssistantVisible: false, smartAssist: smartAssist) == smartAssist)
        #expect(state.visibleSmartAssist(aiEnabled: false, isAIAssistantVisible: false, smartAssist: smartAssist) == nil)
        #expect(state.visibleSmartAssist(aiEnabled: true, isAIAssistantVisible: true, smartAssist: smartAssist) == nil)
    }

    @Test
    func dismissedNotificationStaysHiddenForSamePromptButReappearsForNewIssue() {
        let first = TerminalAISmartAssist(
            kind: .commandNotFound,
            title: "Command not found",
            prompt: "Explain why deployx was not found"
        )
        let second = TerminalAISmartAssist(
            kind: .permissionDenied,
            title: "Permission denied",
            prompt: "Explain why deploy.sh is permission denied"
        )
        var state = TerminalSmartAssistNotificationState()

        state.dismiss(first)

        #expect(state.visibleSmartAssist(aiEnabled: true, isAIAssistantVisible: false, smartAssist: first) == nil)
        #expect(state.visibleSmartAssist(aiEnabled: true, isAIAssistantVisible: false, smartAssist: second) == second)
    }

    @Test
    func syncClearsDismissalWhenAIIsDisabledOrIssueIsGone() {
        let smartAssist = TerminalAISmartAssist(
            kind: .missingPath,
            title: "Missing file or path",
            prompt: "Explain why the requested path is missing"
        )
        var state = TerminalSmartAssistNotificationState()
        state.dismiss(smartAssist)

        state.sync(currentSmartAssist: smartAssist, aiEnabled: false)
        #expect(state.visibleSmartAssist(aiEnabled: true, isAIAssistantVisible: false, smartAssist: smartAssist) == smartAssist)

        state.dismiss(smartAssist)
        state.sync(currentSmartAssist: nil, aiEnabled: true)
        #expect(state.visibleSmartAssist(aiEnabled: true, isAIAssistantVisible: false, smartAssist: smartAssist) == smartAssist)
    }
}
