import Foundation

enum AppLanguageMode: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var locale: Locale? {
        switch self {
        case .system:
            return nil
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    var bundleLocalizationCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-hans"
        }
    }

    static func resolved(from rawValue: String) -> AppLanguageMode {
        AppLanguageMode(rawValue: rawValue) ?? .system
    }

    static func preferredLocale(from rawValue: String?) -> Locale {
        let mode = resolved(from: rawValue ?? AppLanguageMode.system.rawValue)
        return mode.locale ?? .autoupdatingCurrent
    }

    static func preferredLocale(defaults: UserDefaults = .standard) -> Locale {
        preferredLocale(from: defaults.string(forKey: AppSettings.languageModeKey))
    }
}
