import AppKit
import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .shortcuts:
            return "Shortcuts"
        case .advanced:
            return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .shortcuts:
            return "keyboard"
        case .advanced:
            return "slider.horizontal.3"
        }
    }

    var accessibilityIdentifier: String {
        "settings-tab-\(rawValue)"
    }
}

struct RemoraSettingsSheet: View {
    private enum SettingsFocusField: Hashable {
        case downloadDirectoryPath
    }

    @State private var selectedPane: SettingsPane = .general
    @State private var downloadDirectoryDraft = ""
    @State private var downloadDirectoryHighlight = false
    @State private var downloadDirectoryJumpToken = 0
    @State private var recordingShortcutCommand: AppShortcutCommand?
    @State private var shortcutRecorderMonitor: Any?
    @State private var shortcutRecorderMessage: String?
    @State private var shortcutRecorderIsError = false
    @FocusState private var focusedField: SettingsFocusField?
    @EnvironmentObject private var keyboardShortcutStore: AppKeyboardShortcutStore

    @AppStorage(AppSettings.languageModeKey) private var languageModeRawValue = AppLanguageMode.system.rawValue
    @AppStorage(AppSettings.appearanceModeKey) private var appearanceModeRawValue = AppAppearanceMode.system.rawValue
    @AppStorage(AppSettings.downloadDirectoryPathKey) private var downloadDirectoryPath = AppSettings.defaultDownloadDirectoryURL().path
    @AppStorage(AppSettings.serverMetricsActiveRefreshSecondsKey)
    private var serverMetricsActiveRefreshSeconds = AppSettings.defaultServerMetricsActiveRefreshSeconds
    @AppStorage(AppSettings.serverMetricsInactiveRefreshSecondsKey)
    private var serverMetricsInactiveRefreshSeconds = AppSettings.defaultServerMetricsInactiveRefreshSeconds
    @AppStorage(AppSettings.serverMetricsMaxConcurrentFetchesKey)
    private var serverMetricsMaxConcurrentFetches = AppSettings.defaultServerMetricsMaxConcurrentFetches

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 660, minHeight: 410)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("settings-window")
        .onAppear {
            syncDownloadDirectoryDraftFromStorage()
            normalizeServerMetricsSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoraOpenDownloadDirectorySetting)) { _ in
            focusDownloadDirectorySetting()
        }
        .onDisappear {
            stopShortcutCapture(clearSelection: true)
        }
        .onChange(of: serverMetricsActiveRefreshSeconds) {
            normalizeServerMetricsSettings()
        }
        .onChange(of: serverMetricsInactiveRefreshSeconds) {
            normalizeServerMetricsSettings()
        }
        .onChange(of: serverMetricsMaxConcurrentFetches) {
            normalizeServerMetricsSettings()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(SettingsPane.allCases) { pane in
                paneButton(pane)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var content: some View {
        Group {
            switch selectedPane {
            case .general:
                generalPane
            case .shortcuts:
                shortcutsPane
            case .advanced:
                advancedPane
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VisualStyle.leftSidebarBackground.opacity(0.62))
    }

    private func paneButton(_ pane: SettingsPane) -> some View {
        let isSelected = selectedPane == pane
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedPane = pane
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: pane.icon)
                    .font(.system(size: 18, weight: .regular))
                Text(tr(pane.title))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.accentColor : VisualStyle.textSecondary)
            .frame(width: 112, height: 62)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.9) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier(pane.accessibilityIdentifier)
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Application"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VisualStyle.textPrimary)

            Form {
                Picker(
                    tr("Language"),
                    selection: Binding(
                        get: { AppLanguageMode.resolved(from: languageModeRawValue) },
                        set: { mode in
                            languageModeRawValue = mode.rawValue
                        }
                    )
                ) {
                    Text(tr("Follow System")).tag(AppLanguageMode.system)
                    Text(tr("English")).tag(AppLanguageMode.english)
                    Text(tr("Simplified Chinese")).tag(AppLanguageMode.simplifiedChinese)
                }
                .frame(maxWidth: 260, alignment: .leading)

                Picker(
                    tr("Appearance"),
                    selection: Binding(
                        get: { AppAppearanceMode.resolved(from: appearanceModeRawValue) },
                        set: { mode in
                            appearanceModeRawValue = mode.rawValue
                        }
                    )
                ) {
                    Text(tr("System")).tag(AppAppearanceMode.system)
                    Text(tr("Light")).tag(AppAppearanceMode.light)
                    Text(tr("Dark")).tag(AppAppearanceMode.dark)
                }
                .frame(maxWidth: 260, alignment: .leading)
            }
            .formStyle(.grouped)
            .font(.system(size: 13))

            Text(tr("Language changes are applied immediately."))
                .font(.system(size: 12))
                .foregroundStyle(VisualStyle.textSecondary)

            Text(tr("File Manager"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VisualStyle.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Download directory"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VisualStyle.textPrimary)

                HStack(spacing: 8) {
                    TextField(tr("Download directory"), text: $downloadDirectoryDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        .focused($focusedField, equals: .downloadDirectoryPath)
                        .onSubmit {
                            applyDownloadDirectoryDraft()
                        }
                        .accessibilityIdentifier("settings-download-path-field")

                    Button(tr("Choose…")) {
                        chooseDownloadDirectory()
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("settings-download-path-choose")
                }

                Text(tr("Used by File Manager downloads and transfer queue."))
                    .font(.caption)
                    .foregroundStyle(VisualStyle.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(downloadDirectoryHighlight ? 0.95 : 0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(downloadDirectoryHighlight ? Color.accentColor : VisualStyle.borderSoft, lineWidth: downloadDirectoryHighlight ? 1.6 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: downloadDirectoryHighlight)
            .accessibilityIdentifier("settings-download-path-row")

            Spacer(minLength: 0)
        }
        .onChange(of: downloadDirectoryJumpToken) {
            focusedField = .downloadDirectoryPath
            pulseDownloadDirectoryHighlight()
        }
        .accessibilityIdentifier("settings-section-general")
    }

    private var advancedPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Server metrics sampling"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VisualStyle.textPrimary)

            Form {
                HStack(spacing: 12) {
                    Text(tr("Active tab refresh (seconds)"))
                    Stepper(value: $serverMetricsActiveRefreshSeconds, in: 2...30) {
                        Text("\(serverMetricsActiveRefreshSeconds)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(width: 120)
                    .accessibilityIdentifier("settings-metrics-active-refresh")
                }

                HStack(spacing: 12) {
                    Text(tr("Inactive tab refresh (seconds)"))
                    Stepper(value: $serverMetricsInactiveRefreshSeconds, in: 4...90) {
                        Text("\(serverMetricsInactiveRefreshSeconds)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(width: 120)
                    .accessibilityIdentifier("settings-metrics-inactive-refresh")
                }

                HStack(spacing: 12) {
                    Text(tr("Max concurrent metric fetches"))
                    Stepper(value: $serverMetricsMaxConcurrentFetches, in: 1...6) {
                        Text("\(serverMetricsMaxConcurrentFetches)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(width: 120)
                    .accessibilityIdentifier("settings-metrics-max-concurrency")
                }
            }
            .formStyle(.grouped)
            .font(.system(size: 13))

            Text(tr("Higher refresh and concurrency improve responsiveness but increase local and remote load."))
                .font(.system(size: 12))
                .foregroundStyle(VisualStyle.textSecondary)
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("settings-section-advanced")
    }

    private var shortcutsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("Keyboard Shortcuts"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VisualStyle.textPrimary)

                Text(tr("Use common shortcuts and customize them for your workflow."))
                    .font(.system(size: 12))
                    .foregroundStyle(VisualStyle.textSecondary)

                shortcutConflictsCard

                if let shortcutRecorderMessage {
                    Label(shortcutRecorderMessage, systemImage: shortcutRecorderIsError ? "exclamationmark.triangle.fill" : "keyboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(shortcutRecorderIsError ? Color.orange : VisualStyle.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.white.opacity(0.68))
                        )
                }

                VStack(spacing: 8) {
                    ForEach(AppShortcutCommand.allCases) { command in
                        shortcutRow(for: command)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .accessibilityIdentifier("settings-section-shortcuts")
    }

    private var shortcutConflictsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: keyboardShortcutStore.conflicts.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(keyboardShortcutStore.conflicts.isEmpty ? Color.green : Color.orange)
                Text(tr("Shortcut conflicts"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VisualStyle.textPrimary)
            }

            if keyboardShortcutStore.conflicts.isEmpty {
                Text(tr("No shortcut conflicts detected."))
                    .font(.system(size: 12))
                    .foregroundStyle(VisualStyle.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(keyboardShortcutStore.conflicts) { conflict in
                        let commandNames = conflict.commands
                            .map { commandTitle(for: $0) }
                            .joined(separator: " / ")
                        Text("\(conflict.shortcut.displayText)  \(commandNames)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(VisualStyle.textPrimary)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(keyboardShortcutStore.conflicts.isEmpty ? VisualStyle.borderSoft : Color.orange.opacity(0.8), lineWidth: 1)
        )
    }

    private func shortcutRow(for command: AppShortcutCommand) -> some View {
        let isRecording = recordingShortcutCommand == command
        let displayShortcut = keyboardShortcutStore.shortcut(for: command)?.displayText ?? tr("Not Set")
        let hasConflict = keyboardShortcutStore.conflict(for: command) != nil
        let isCustomized = keyboardShortcutStore.hasCustomBinding(for: command)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(commandTitle(for: command))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VisualStyle.textPrimary)

                    if hasConflict {
                        Text(tr("Conflict with another command"))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.orange)
                    } else if isCustomized {
                        Text(tr("Customized"))
                            .font(.system(size: 11))
                            .foregroundStyle(VisualStyle.textSecondary)
                    }
                }

                Spacer(minLength: 6)

                Button {
                    beginShortcutCapture(for: command)
                } label: {
                    Text(isRecording ? tr("Press shortcut...") : displayShortcut)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isRecording ? Color.accentColor : VisualStyle.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 116)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    isRecording ? Color.accentColor : (hasConflict ? Color.orange.opacity(0.85) : VisualStyle.borderSoft),
                                    lineWidth: isRecording ? 1.5 : 1
                                )
                        )
                }
                .buttonStyle(.plain)

                Button(tr("Unbind")) {
                    keyboardShortcutStore.unbindShortcut(for: command)
                    if recordingShortcutCommand == command {
                        stopShortcutCapture(clearSelection: true)
                    }
                }
                .controlSize(.small)

                Button(tr("Default")) {
                    keyboardShortcutStore.restoreDefault(for: command)
                    if recordingShortcutCommand == command {
                        stopShortcutCapture(clearSelection: true)
                    }
                }
                .controlSize(.small)
                .disabled(!isCustomized)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(hasConflict ? Color.orange.opacity(0.85) : VisualStyle.borderSoft, lineWidth: 1)
        )
    }

    private func beginShortcutCapture(for command: AppShortcutCommand) {
        stopShortcutCapture(clearSelection: true)
        recordingShortcutCommand = command
        shortcutRecorderMessage = tr("Press a key combination now. Press Esc to cancel.")
        shortcutRecorderIsError = false

        shortcutRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleShortcutRecorderEvent(event)
        }
    }

    private func stopShortcutCapture(clearSelection: Bool) {
        if let shortcutRecorderMonitor {
            NSEvent.removeMonitor(shortcutRecorderMonitor)
            self.shortcutRecorderMonitor = nil
        }
        if clearSelection {
            recordingShortcutCommand = nil
        }
    }

    private func handleShortcutRecorderEvent(_ event: NSEvent) -> NSEvent? {
        guard let command = recordingShortcutCommand else {
            return event
        }

        if event.keyCode == 53 {
            shortcutRecorderMessage = tr("Shortcut update canceled.")
            shortcutRecorderIsError = false
            stopShortcutCapture(clearSelection: true)
            return nil
        }

        guard let shortcut = AppKeyboardShortcut.from(event: event) else {
            shortcutRecorderMessage = tr("Shortcut must include Command, Option, or Control.")
            shortcutRecorderIsError = true
            NSSound.beep()
            return nil
        }

        keyboardShortcutStore.setShortcut(shortcut, for: command)
        shortcutRecorderMessage = "\(commandTitle(for: command)) \(tr("updated to")) \(shortcut.displayText)"
        shortcutRecorderIsError = false
        stopShortcutCapture(clearSelection: true)
        return nil
    }

    private func commandTitle(for command: AppShortcutCommand) -> String {
        L10n.tr(command.titleKey, fallback: command.fallbackTitle)
    }

    private func focusDownloadDirectorySetting() {
        syncDownloadDirectoryDraftFromStorage()
        withAnimation(.easeInOut(duration: 0.12)) {
            selectedPane = .general
        }
        DispatchQueue.main.async {
            downloadDirectoryJumpToken += 1
        }
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = tr("Choose…")
        panel.directoryURL = resolvedDownloadDirectoryURL(from: downloadDirectoryDraft)

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }
        downloadDirectoryDraft = selectedURL.standardizedFileURL.path
        applyDownloadDirectoryDraft()
    }

    private func applyDownloadDirectoryDraft() {
        let resolvedURL = resolvedDownloadDirectoryURL(from: downloadDirectoryDraft)
        downloadDirectoryDraft = resolvedURL.path
        guard downloadDirectoryPath != resolvedURL.path else { return }
        downloadDirectoryPath = resolvedURL.path
        NotificationCenter.default.post(
            name: .remoraDownloadDirectoryDidChange,
            object: resolvedURL.path,
            userInfo: ["path": resolvedURL.path]
        )
    }

    private func syncDownloadDirectoryDraftFromStorage() {
        let resolvedURL = resolvedDownloadDirectoryURL(from: downloadDirectoryPath)
        if downloadDirectoryPath != resolvedURL.path {
            downloadDirectoryPath = resolvedURL.path
            NotificationCenter.default.post(
                name: .remoraDownloadDirectoryDidChange,
                object: resolvedURL.path,
                userInfo: ["path": resolvedURL.path]
            )
        }
        if downloadDirectoryDraft != resolvedURL.path {
            downloadDirectoryDraft = resolvedURL.path
        }
    }

    private func resolvedDownloadDirectoryURL(from rawPath: String) -> URL {
        AppSettings.resolvedDownloadDirectoryURL(from: rawPath)
    }

    private func pulseDownloadDirectoryHighlight() {
        downloadDirectoryHighlight = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            downloadDirectoryHighlight = false
        }
    }

    private func normalizeServerMetricsSettings() {
        let normalizedActive = AppSettings.clampedServerMetricsActiveRefreshSeconds(serverMetricsActiveRefreshSeconds)
        let normalizedInactiveCandidate = AppSettings.clampedServerMetricsInactiveRefreshSeconds(serverMetricsInactiveRefreshSeconds)
        let normalizedInactive = max(normalizedInactiveCandidate, normalizedActive)
        let normalizedConcurrent = AppSettings.clampedServerMetricsMaxConcurrentFetches(serverMetricsMaxConcurrentFetches)

        if normalizedActive != serverMetricsActiveRefreshSeconds {
            serverMetricsActiveRefreshSeconds = normalizedActive
        }
        if normalizedInactive != serverMetricsInactiveRefreshSeconds {
            serverMetricsInactiveRefreshSeconds = normalizedInactive
        }
        if normalizedConcurrent != serverMetricsMaxConcurrentFetches {
            serverMetricsMaxConcurrentFetches = normalizedConcurrent
        }
    }

    private func tr(_ key: String) -> String {
        L10n.tr(key, fallback: key)
    }
}
