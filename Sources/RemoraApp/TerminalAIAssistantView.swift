import AppKit
import SwiftUI

struct TerminalAIAssistantView: View {
    @ObservedObject var coordinator: TerminalAIAssistantCoordinator
    @ObservedObject var runtime: TerminalRuntime

    @State private var promptDraft = ""
    @State private var submissionError: String?
    @State private var pendingRunCommand: TerminalAICommandSuggestion?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .overlay(VisualStyle.borderSoft)

            quickActions

            if let submissionError {
                Text(submissionError)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if coordinator.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(coordinator.messages) { message in
                            messageCard(message)
                        }
                    }
                }
                .padding(12)
            }

            Divider()
                .overlay(VisualStyle.borderSoft)

            composer
        }
        .frame(minWidth: 280, idealWidth: 340, maxWidth: 380, maxHeight: .infinity, alignment: .topLeading)
        .background(VisualStyle.settingsSurfaceBackground)
        .accessibilityIdentifier("terminal-ai-drawer")
        .alert(tr("Run AI command?"), isPresented: Binding(
            get: { pendingRunCommand != nil },
            set: { isPresented in
                if !isPresented {
                    pendingRunCommand = nil
                }
            }
        )) {
            Button(tr("Cancel"), role: .cancel) {
                pendingRunCommand = nil
            }
            Button(tr("Run")) {
                if let command = pendingRunCommand?.command {
                    runtime.runAssistantCommand(command)
                }
                pendingRunCommand = nil
            }
        } message: {
            Text(pendingRunCommand?.command ?? tr("This command will be sent to the current terminal session."))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("Terminal AI"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VisualStyle.textPrimary)

            if let workingDirectory = runtime.workingDirectory, !workingDirectory.isEmpty {
                Text(workingDirectory)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(VisualStyle.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Quick Actions"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VisualStyle.textSecondary)

            HStack(spacing: 8) {
                actionButton(title: tr("Explain Output"), prompt: "Explain the latest terminal output in plain language.")
                actionButton(title: tr("Suggest Next Command"), prompt: "Suggest the safest next command for this terminal session.")
            }

            actionButton(
                title: tr("Fix Last Error"),
                prompt: coordinator.smartAssist?.prompt ?? "Explain the latest terminal error and suggest the safest next command."
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func actionButton(title: String, prompt: String) -> some View {
        Button(title) {
            submit(prompt)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("No AI messages yet."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VisualStyle.textPrimary)

            Text(tr("Ask Terminal AI about terminal output, next commands, or the safest way to recover from an error."))
                .font(.system(size: 12))
                .foregroundStyle(VisualStyle.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VisualStyle.settingsSubtleBackground)
        )
    }

    @ViewBuilder
    private func messageCard(_ message: TerminalAIAssistantMessage) -> some View {
        if let prompt = message.prompt {
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("You"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(prompt)
                    .font(.system(size: 13))
                    .foregroundStyle(VisualStyle.textPrimary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(VisualStyle.settingsSubtleBackground)
            )
        }

        if let response = message.response {
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("Terminal AI"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text(response.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(VisualStyle.textPrimary)

                if !response.commands.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(response.commands.enumerated()), id: \.offset) { _, command in
                            commandCard(command)
                        }
                    }
                }

                if !response.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Warnings"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.orange)

                        ForEach(response.warnings, id: \.self) { warning in
                            Text("• \(warning)")
                                .font(.system(size: 12))
                                .foregroundStyle(VisualStyle.textSecondary)
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(VisualStyle.borderSoft, lineWidth: 1)
            )
        }
    }

    private func commandCard(_ suggestion: TerminalAICommandSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(suggestion.command)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(VisualStyle.textPrimary)
                    .textSelection(.enabled)

                Spacer(minLength: 8)

                Text(riskLabel(for: suggestion.risk))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(riskColor(for: suggestion.risk))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(riskColor(for: suggestion.risk).opacity(0.14), in: Capsule())
            }

            Text(suggestion.purpose)
                .font(.system(size: 12))
                .foregroundStyle(VisualStyle.textSecondary)

            HStack(spacing: 8) {
                Button(tr("Insert")) {
                    runtime.insertAssistantCommand(suggestion.command)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(tr("Run")) {
                    pendingRunCommand = suggestion
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(tr("Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(suggestion.command, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VisualStyle.settingsSubtleBackground)
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(tr("Ask Terminal AI"), text: $promptDraft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .accessibilityIdentifier("terminal-ai-input")

            HStack {
                Spacer()
                Button(tr("Send")) {
                    submit(promptDraft)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(promptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.isResponding)
                .accessibilityIdentifier("terminal-ai-send")
            }
        }
        .padding(12)
    }

    private func submit(_ prompt: String) {
        Task {
            do {
                try await coordinator.submit(prompt)
                await MainActor.run {
                    promptDraft = ""
                    submissionError = nil
                }
            } catch let error as TerminalAIAssistantCoordinatorError {
                await MainActor.run {
                    submissionError = errorMessage(for: error)
                }
            } catch {
                await MainActor.run {
                    submissionError = tr("Terminal AI request failed.")
                }
            }
        }
    }

    private func errorMessage(for error: TerminalAIAssistantCoordinatorError) -> String {
        switch error {
        case .sessionNotBound:
            return tr("Terminal AI is not attached to a session yet.")
        case .aiDisabled:
            return tr("Enable Terminal AI in Settings before sending requests.")
        case .emptyPrompt:
            return tr("Enter a prompt before sending it to Terminal AI.")
        case .missingAPIKey:
            return tr("Add an AI API key in Settings before using Terminal AI.")
        }
    }

    private func riskLabel(for risk: TerminalAICommandRisk) -> String {
        switch risk {
        case .safe:
            return tr("Safe")
        case .review:
            return tr("Review")
        case .danger:
            return tr("Danger")
        }
    }

    private func riskColor(for risk: TerminalAICommandRisk) -> Color {
        switch risk {
        case .safe:
            return .green
        case .review:
            return .orange
        case .danger:
            return .red
        }
    }

    private func tr(_ key: String) -> String {
        L10n.tr(key, fallback: key)
    }
}
