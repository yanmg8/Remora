import RemoraCore

extension HostQuickCommand {
    func executionPayload() -> String? {
        let body = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return "\(body)\n"
    }
}
