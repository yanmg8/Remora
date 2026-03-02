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
}
