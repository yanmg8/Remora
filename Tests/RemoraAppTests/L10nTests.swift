import Foundation
import Testing
@testable import RemoraApp

struct L10nTests {
    @Test
    func languageOverrideReturnsSimplifiedChineseString() {
        let value = L10n.tr("Language", fallback: "Language", modeOverride: .simplifiedChinese)
        #expect(value == "语言")
    }

    @Test
    func languageOverrideReturnsEnglishString() {
        let value = L10n.tr("Language", fallback: "Language", modeOverride: .english)
        #expect(value == "Language")
    }

    @Test
    func resolvesResourceBundleInsideAppContentsResources() throws {
        let tempRoot = try makeTemporaryDirectory()
        let appBundleURL = tempRoot.appending(path: "Remora.app", directoryHint: .isDirectory)
        let resourcesURL = appBundleURL.appending(path: "Contents/Resources", directoryHint: .isDirectory)
        let bundleURL = resourcesURL.appending(path: "Remora_RemoraApp.bundle", directoryHint: .isDirectory)
        try makeResourceBundle(at: bundleURL)

        let bundle = L10n.resolveResourceBundle(
            mainBundleURL: appBundleURL,
            mainResourceURL: resourcesURL,
            loadedBundleURLs: [],
            environment: [:]
        )

        #expect(bundle?.bundleURL.standardizedFileURL == bundleURL.standardizedFileURL)
    }

    @Test
    func resolvesResourceBundleNextToSwiftPMTestBundle() throws {
        let tempRoot = try makeTemporaryDirectory()
        let testBundleURL = tempRoot.appending(path: "RemoraPackageTests.xctest", directoryHint: .isDirectory)
        let bundleURL = tempRoot.appending(path: "Remora_RemoraApp.bundle", directoryHint: .isDirectory)
        try makeResourceBundle(at: bundleURL)

        let bundle = L10n.resolveResourceBundle(
            mainBundleURL: testBundleURL,
            mainResourceURL: testBundleURL.appending(path: "Contents/Resources", directoryHint: .isDirectory),
            loadedBundleURLs: [],
            environment: [:]
        )

        #expect(bundle?.bundleURL.standardizedFileURL == bundleURL.standardizedFileURL)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeResourceBundle(at bundleURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>io.github.wuujiawei.remora.tests</string>
            <key>CFBundleName</key>
            <string>RemoraTests</string>
            <key>CFBundlePackageType</key>
            <string>BNDL</string>
        </dict>
        </plist>
        """
        try infoPlist.write(
            to: bundleURL.appending(path: "Info.plist"),
            atomically: true,
            encoding: .utf8
        )
    }
}
