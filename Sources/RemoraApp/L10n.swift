import Foundation

enum L10n {
    private static let resourceBundle = resolveResourceBundle() ?? .main
    private static let resourceBundleName = "Remora_RemoraApp.bundle"

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

    static func resolveResourceBundle(
        mainBundleURL: URL = Bundle.main.bundleURL,
        mainResourceURL: URL? = Bundle.main.resourceURL,
        loadedBundleURLs: [URL] = (Bundle.allBundles + Bundle.allFrameworks).map(\.bundleURL),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> Bundle? {
        if let overridePath = environment["REMORA_RESOURCE_BUNDLE_PATH"], !overridePath.isEmpty {
            let overrideURL = URL(fileURLWithPath: overridePath)
            if let bundle = Bundle(url: overrideURL) {
                return bundle
            }
        }

        let buildBundleURLs = sourceRootBundleURLs(fileManager: fileManager)

        for candidateURL in resourceBundleCandidateURLs(
            mainBundleURL: mainBundleURL,
            mainResourceURL: mainResourceURL,
            loadedBundleURLs: loadedBundleURLs + buildBundleURLs
        ) where fileManager.fileExists(atPath: candidateURL.path) {
            if let bundle = Bundle(url: candidateURL) {
                return bundle
            }
        }

        return nil
    }

    static func resourceBundleCandidateURLs(
        mainBundleURL: URL,
        mainResourceURL: URL?,
        loadedBundleURLs: [URL]
    ) -> [URL] {
        var candidates: [URL] = []
        var visitedPaths: Set<String> = []

        func append(_ url: URL?) {
            guard let url else { return }
            let standardizedURL = url.standardizedFileURL
            guard visitedPaths.insert(standardizedURL.path).inserted else { return }
            candidates.append(standardizedURL)
        }

        func appendBundleNameAcrossAncestors(startingAt url: URL?, maxDepth: Int = 8) {
            guard var currentURL = url?.standardizedFileURL else { return }
            for _ in 0..<maxDepth {
                append(currentURL)
                append(currentURL.appendingPathComponent(resourceBundleName, isDirectory: true))
                currentURL.deleteLastPathComponent()
            }
        }

        append(mainResourceURL?.appendingPathComponent(resourceBundleName, isDirectory: true))
        appendBundleNameAcrossAncestors(startingAt: mainBundleURL)
        appendBundleNameAcrossAncestors(startingAt: Bundle.main.executableURL?.deletingLastPathComponent())
        appendBundleNameAcrossAncestors(
            startingAt: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        )

        for bundleURL in loadedBundleURLs {
            appendBundleNameAcrossAncestors(startingAt: bundleURL)
            append(bundleURL.appendingPathComponent("Contents/Resources/\(resourceBundleName)", isDirectory: true))
        }

        return candidates.filter { $0.lastPathComponent == resourceBundleName }
    }

    static func sourceRootBundleURLs(fileManager: FileManager = .default) -> [URL] {
        let sourceRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildRootURL = sourceRootURL.appendingPathComponent(".build", isDirectory: true)

        guard let enumerator = fileManager.enumerator(
            at: buildRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var matches: [URL] = []
        for case let candidateURL as URL in enumerator {
            if candidateURL.lastPathComponent == resourceBundleName {
                matches.append(candidateURL)
                enumerator.skipDescendants()
            }
        }
        return matches
    }
}
