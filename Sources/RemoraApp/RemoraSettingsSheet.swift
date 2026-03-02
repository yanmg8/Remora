import AppKit
import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .advanced:
            return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
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
    @FocusState private var focusedField: SettingsFocusField?

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
                Text(pane.title)
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
            Text("Application")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VisualStyle.textPrimary)

            Form {
                Picker(
                    "Language",
                    selection: Binding(
                        get: { AppLanguageMode.resolved(from: languageModeRawValue) },
                        set: { mode in
                            languageModeRawValue = mode.rawValue
                        }
                    )
                ) {
                    Text("Follow System").tag(AppLanguageMode.system)
                    Text("English").tag(AppLanguageMode.english)
                    Text("Simplified Chinese").tag(AppLanguageMode.simplifiedChinese)
                }
                .frame(maxWidth: 260, alignment: .leading)

                Picker(
                    "Appearance",
                    selection: Binding(
                        get: { AppAppearanceMode.resolved(from: appearanceModeRawValue) },
                        set: { mode in
                            appearanceModeRawValue = mode.rawValue
                        }
                    )
                ) {
                    Text("System").tag(AppAppearanceMode.system)
                    Text("Light").tag(AppAppearanceMode.light)
                    Text("Dark").tag(AppAppearanceMode.dark)
                }
                .frame(maxWidth: 260, alignment: .leading)
            }
            .formStyle(.grouped)
            .font(.system(size: 13))

            Text("Language changes are applied immediately.")
                .font(.system(size: 12))
                .foregroundStyle(VisualStyle.textSecondary)

            Text("File Manager")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VisualStyle.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Download directory")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VisualStyle.textPrimary)

                HStack(spacing: 8) {
                    TextField("Download directory", text: $downloadDirectoryDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        .focused($focusedField, equals: .downloadDirectoryPath)
                        .onSubmit {
                            applyDownloadDirectoryDraft()
                        }
                        .accessibilityIdentifier("settings-download-path-field")

                    Button("Choose…") {
                        chooseDownloadDirectory()
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("settings-download-path-choose")
                }

                Text("Used by File Manager downloads and transfer queue.")
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
            Text("Server metrics sampling")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VisualStyle.textPrimary)

            Form {
                HStack(spacing: 12) {
                    Text("Active tab refresh (seconds)")
                    Stepper(value: $serverMetricsActiveRefreshSeconds, in: 2...30) {
                        Text("\(serverMetricsActiveRefreshSeconds)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(width: 120)
                    .accessibilityIdentifier("settings-metrics-active-refresh")
                }

                HStack(spacing: 12) {
                    Text("Inactive tab refresh (seconds)")
                    Stepper(value: $serverMetricsInactiveRefreshSeconds, in: 4...90) {
                        Text("\(serverMetricsInactiveRefreshSeconds)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(width: 120)
                    .accessibilityIdentifier("settings-metrics-inactive-refresh")
                }

                HStack(spacing: 12) {
                    Text("Max concurrent metric fetches")
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

            Text("Higher refresh and concurrency improve responsiveness but increase local and remote load.")
                .font(.system(size: 12))
                .foregroundStyle(VisualStyle.textSecondary)
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("settings-section-advanced")
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
        panel.prompt = "Choose"
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
}
