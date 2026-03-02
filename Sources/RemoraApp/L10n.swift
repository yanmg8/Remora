import Foundation

enum L10n {
    static func tr(_ key: String, fallback: String, modeOverride: AppLanguageMode? = nil) -> String {
        let mode: AppLanguageMode = modeOverride ?? AppLanguageMode.resolved(
            from: UserDefaults.standard.string(forKey: AppSettings.languageModeKey) ?? AppLanguageMode.system.rawValue
        )

        if let localizationCode = mode.bundleLocalizationCode,
           let path = Bundle.module.path(forResource: localizationCode, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            return localizedBundle.localizedString(forKey: key, value: fallback, table: nil)
        }

        return Bundle.module.localizedString(forKey: key, value: fallback, table: nil)
    }
}
