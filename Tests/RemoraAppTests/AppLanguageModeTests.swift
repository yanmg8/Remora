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
    func preferredLocaleFromDefaultsUsesStoredLanguageMode() throws {
        let suiteName = "AppLanguageModeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create defaults suite")
            return
        }
        defaults.set(AppLanguageMode.english.rawValue, forKey: AppSettings.languageModeKey)

        #expect(AppLanguageMode.preferredLocale(defaults: defaults).identifier == "en")

        defaults.removePersistentDomain(forName: suiteName)
    }
}
