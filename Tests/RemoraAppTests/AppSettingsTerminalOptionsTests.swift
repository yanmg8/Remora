import Foundation
import Testing
@testable import RemoraApp

struct AppSettingsTerminalOptionsTests {
    @Test
    func terminalOptionDefaultsResolveWhenUnset() {
        let suiteName = "AppSettingsTerminalOptionsTests.defaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(AppSettings.resolvedTerminalWordSeparators(defaults: defaults) == AppSettings.defaultTerminalWordSeparators)
        #expect(AppSettings.resolvedTerminalScrollSensitivity(defaults: defaults) == AppSettings.defaultTerminalScrollSensitivity)
        #expect(AppSettings.resolvedTerminalFastScrollSensitivity(defaults: defaults) == AppSettings.defaultTerminalFastScrollSensitivity)
        #expect(AppSettings.resolvedTerminalScrollOnUserInput(defaults: defaults) == true)
        #expect(AppSettings.resolvedTerminalCommandComposerPlacement(defaults: defaults) == .bottom)
    }

    @Test
    func terminalOptionValuesAreClamped() {
        let suiteName = "AppSettingsTerminalOptionsTests.clamp.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(0.01, forKey: AppSettings.terminalScrollSensitivityKey)
        defaults.set(300.0, forKey: AppSettings.terminalFastScrollSensitivityKey)
        defaults.set(false, forKey: AppSettings.terminalScrollOnUserInputKey)
        defaults.set("::", forKey: AppSettings.terminalWordSeparatorsKey)

        #expect(AppSettings.resolvedTerminalScrollSensitivity(defaults: defaults) == 0.1)
        #expect(AppSettings.resolvedTerminalFastScrollSensitivity(defaults: defaults) == 12.0)
        #expect(AppSettings.resolvedTerminalScrollOnUserInput(defaults: defaults) == false)
        #expect(AppSettings.resolvedTerminalWordSeparators(defaults: defaults) == "::")
    }

    @Test
    func terminalCommandComposerPlacementRoundTrips() {
        let suiteName = "AppSettingsTerminalOptionsTests.placement.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("top", forKey: AppSettings.terminalCommandComposerPlacementKey)
        #expect(AppSettings.resolvedTerminalCommandComposerPlacement(defaults: defaults) == .top)

        defaults.set("bottom", forKey: AppSettings.terminalCommandComposerPlacementKey)
        #expect(AppSettings.resolvedTerminalCommandComposerPlacement(defaults: defaults) == .bottom)
    }

}
