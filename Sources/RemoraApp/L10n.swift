import Foundation

enum L10n {
    private static let resourceBundle: Bundle = {
        let fileManager = FileManager.default
        let explicitCandidates = [
            Bundle.main.resourceURL?.appendingPathComponent("Remora_RemoraApp.bundle", isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Remora_RemoraApp.bundle", isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent("Remora_RemoraApp.bundle", isDirectory: true),
        ]

        for candidate in explicitCandidates.compactMap({ $0 }) {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        let searchRoots = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true),
        ]

        for root in searchRoots.compactMap({ $0 }) {
            guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            if let bundleURL = entries.first(where: {
                $0.pathExtension == "bundle" && $0.lastPathComponent.hasSuffix("_RemoraApp.bundle")
            }), let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }

        return Bundle.main
    }()

    static func tr(_ key: String, fallback: String, modeOverride: AppLanguageMode? = nil) -> String {
        let mode: AppLanguageMode = modeOverride ?? AppLanguageMode.resolved(
            from: UserDefaults.standard.string(forKey: AppSettings.languageModeKey) ?? AppLanguageMode.system.rawValue
        )

        if let localizationCode = mode.bundleLocalizationCode,
           let path = resourceBundle.path(forResource: localizationCode, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            return localizedBundle.localizedString(forKey: key, value: fallback, table: nil)
        }

        return resourceBundle.localizedString(forKey: key, value: fallback, table: nil)
    }
}
