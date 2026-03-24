import Foundation
import SwiftUI
import RemoraCore

struct AppPreferencesSnapshot: Codable, Equatable {
    var appearanceModeRawValue: String
    var languageModeRawValue: String
    var downloadDirectoryPath: String
    var aiEnabled: Bool
    var aiProviderRawValue: String
    var aiAPIFormatRawValue: String
    var aiBaseURL: String
    var aiModel: String
    var aiLanguageRawValue: String
    var aiSmartAssistEnabled: Bool
    var aiIncludeWorkingDirectory: Bool
    var aiIncludeTranscript: Bool
    var aiTranscriptLineCount: Int
    var aiRequireRunConfirmation: Bool
    var aiAPIKey: String
    var connectionInfoPasswordCopyMutedUntilEpoch: Double
    var connectionInfoPasswordCopyMuteForever: Bool
    var serverMetricsActiveRefreshSeconds: Int
    var serverMetricsInactiveRefreshSeconds: Int
    var serverMetricsMaxConcurrentFetches: Int

    static func defaultValue(fileManager: FileManager = .default) -> AppPreferencesSnapshot {
        AppPreferencesSnapshot(
            appearanceModeRawValue: AppAppearanceMode.system.rawValue,
            languageModeRawValue: AppLanguageMode.system.rawValue,
            downloadDirectoryPath: AppSettings.defaultDownloadDirectoryURL(fileManager: fileManager).path,
            aiEnabled: AppSettings.defaultAIEnabled,
            aiProviderRawValue: AppSettings.defaultAIActiveProvider,
            aiAPIFormatRawValue: AppSettings.defaultAIAPIFormat,
            aiBaseURL: AppSettings.defaultAIBaseURL,
            aiModel: AppSettings.defaultAIModel,
            aiLanguageRawValue: AppSettings.defaultAILanguage,
            aiSmartAssistEnabled: AppSettings.defaultAISmartAssistEnabled,
            aiIncludeWorkingDirectory: AppSettings.defaultAIIncludeWorkingDirectory,
            aiIncludeTranscript: AppSettings.defaultAIIncludeTranscript,
            aiTranscriptLineCount: AppSettings.defaultAITerminalTranscriptLineCount,
            aiRequireRunConfirmation: AppSettings.defaultAIRequireRunConfirmation,
            aiAPIKey: "",
            connectionInfoPasswordCopyMutedUntilEpoch: 0,
            connectionInfoPasswordCopyMuteForever: false,
            serverMetricsActiveRefreshSeconds: AppSettings.defaultServerMetricsActiveRefreshSeconds,
            serverMetricsInactiveRefreshSeconds: AppSettings.defaultServerMetricsInactiveRefreshSeconds,
            serverMetricsMaxConcurrentFetches: AppSettings.defaultServerMetricsMaxConcurrentFetches
        )
    }

    func normalized(fileManager: FileManager = .default) -> AppPreferencesSnapshot {
        var normalized = self
        normalized.downloadDirectoryPath = AppSettings.resolvedDownloadDirectoryURL(
            from: downloadDirectoryPath,
            fileManager: fileManager
        ).path
        normalized.aiTranscriptLineCount = AppSettings.clampedAITerminalTranscriptLineCount(aiTranscriptLineCount)
        normalized.aiAPIKey = aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.serverMetricsActiveRefreshSeconds = AppSettings.clampedServerMetricsActiveRefreshSeconds(serverMetricsActiveRefreshSeconds)
        normalized.serverMetricsInactiveRefreshSeconds = AppSettings.clampedServerMetricsInactiveRefreshSeconds(serverMetricsInactiveRefreshSeconds)
        normalized.serverMetricsMaxConcurrentFetches = AppSettings.clampedServerMetricsMaxConcurrentFetches(serverMetricsMaxConcurrentFetches)
        return normalized
    }
}

final class AppPreferences: ObservableObject, @unchecked Sendable {
    static let shared = AppPreferences()

    @Published private(set) var snapshot: AppPreferencesSnapshot

    private let fileManager: FileManager
    private let store: RemoraJSONFileStore<AppPreferencesSnapshot>

    init(
        fileURL: URL = RemoraConfigPaths.fileURL(for: .settings),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.store = RemoraJSONFileStore(fileURL: fileURL)
        self.snapshot = AppPreferences.loadInitialSnapshot(store: store, fileManager: fileManager)
    }

    func value<Value>(for keyPath: KeyPath<AppPreferencesSnapshot, Value>) -> Value {
        snapshot[keyPath: keyPath]
    }

    func set<Value>(_ value: Value, for keyPath: WritableKeyPath<AppPreferencesSnapshot, Value>) {
        var updated = snapshot
        updated[keyPath: keyPath] = value
        apply(updated)
    }

    func reload() {
        snapshot = Self.loadInitialSnapshot(store: store, fileManager: fileManager)
    }

    private func apply(_ updated: AppPreferencesSnapshot) {
        let normalized = updated.normalized(fileManager: fileManager)
        let previousDownloadPath = snapshot.downloadDirectoryPath
        snapshot = normalized
        try? store.save(normalized)

        if previousDownloadPath != normalized.downloadDirectoryPath {
            NotificationCenter.default.post(
                name: .remoraDownloadDirectoryDidChange,
                object: normalized.downloadDirectoryPath,
                userInfo: ["path": normalized.downloadDirectoryPath]
            )
        }
    }

    private static func loadInitialSnapshot(
        store: RemoraJSONFileStore<AppPreferencesSnapshot>,
        fileManager: FileManager
    ) -> AppPreferencesSnapshot {
        let defaults = AppPreferencesSnapshot.defaultValue(fileManager: fileManager)
        guard let loaded = try? store.load() else {
            return defaults
        }
        return loaded.normalized(fileManager: fileManager)
    }
}

@MainActor
@propertyWrapper
struct RemoraStored<Value>: DynamicProperty {
    @ObservedObject private var preferences: AppPreferences
    private let keyPath: WritableKeyPath<AppPreferencesSnapshot, Value>

    init(_ keyPath: WritableKeyPath<AppPreferencesSnapshot, Value>, preferences: AppPreferences = .shared) {
        self.keyPath = keyPath
        self._preferences = ObservedObject(wrappedValue: preferences)
    }

    var wrappedValue: Value {
        get { preferences.value(for: keyPath) }
        nonmutating set { preferences.set(newValue, for: keyPath) }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { preferences.value(for: keyPath) },
            set: { preferences.set($0, for: keyPath) }
        )
    }
}
