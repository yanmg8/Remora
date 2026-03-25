struct TerminalSmartAssistNotificationState: Equatable {
    private(set) var dismissedPrompt: String?

    func visibleSmartAssist(
        aiEnabled: Bool,
        isAIAssistantVisible: Bool,
        smartAssist: TerminalAISmartAssist?
    ) -> TerminalAISmartAssist? {
        guard aiEnabled, !isAIAssistantVisible, let smartAssist else { return nil }
        guard dismissedPrompt != smartAssist.prompt else { return nil }
        return smartAssist
    }

    mutating func dismiss(_ smartAssist: TerminalAISmartAssist) {
        dismissedPrompt = smartAssist.prompt
    }

    mutating func sync(currentSmartAssist: TerminalAISmartAssist?, aiEnabled: Bool) {
        if !aiEnabled || currentSmartAssist == nil {
            dismissedPrompt = nil
        }
    }
}
