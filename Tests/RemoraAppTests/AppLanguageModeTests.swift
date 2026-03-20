import Foundation
import Testing
@testable import RemoraApp

struct AppLanguageModeTests {
    @Test
    func resolvedFallsBackToSystemForUnknownValue() {
        #expect(AppLanguageMode.resolved(from: "unknown") == .system)
    }

    @Test
    func resolvedParsesKnownValues() {
        #expect(AppLanguageMode.resolved(from: "system") == .system)
        #expect(AppLanguageMode.resolved(from: "english") == .english)
        #expect(AppLanguageMode.resolved(from: "simplifiedChinese") == .simplifiedChinese)
    }

    @Test
    func preferredLocaleFromRawValueUsesLanguageMode() {
        #expect(AppLanguageMode.preferredLocale(from: AppLanguageMode.english.rawValue).identifier == "en")
        #expect(AppLanguageMode.preferredLocale(from: AppLanguageMode.simplifiedChinese.rawValue).identifier == "zh-Hans")
    }

    @Test
    func preferredLocaleFromPreferencesUsesStoredLanguageMode() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("app-language-mode-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let preferences = AppPreferences(fileURL: root.appendingPathComponent("settings.json"))
        preferences.set(AppLanguageMode.english.rawValue, for: \.languageModeRawValue)

        #expect(AppLanguageMode.preferredLocale(preferences: preferences).identifier == "en")
    }
}
