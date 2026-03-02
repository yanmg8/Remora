import AppKit
import Foundation
import Testing
@testable import RemoraApp

@MainActor
struct AppKeyboardShortcutStoreTests {
    @Test
    func usesExpectedDefaultShortcuts() {
        let store = makeStore()

        #expect(store.shortcut(for: .openSettings)?.displayText == "⌘,")
        #expect(store.shortcut(for: .newSSHConnection)?.displayText == "⌘⇧N")
        #expect(store.shortcut(for: .importConnections)?.displayText == "⌘I")
        #expect(store.shortcut(for: .exportConnections)?.displayText == "⌘E")
    }

    @Test
    func persistsCustomAndUnboundShortcuts() {
        let suiteName = "remora-shortcuts-tests-\(UUID().uuidString)"
        let storageKey = "shortcuts-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults suite.")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppKeyboardShortcutStore(userDefaults: defaults, storageKey: storageKey)
        store.unbindShortcut(for: .importConnections)
        store.setShortcut(
            AppKeyboardShortcut(keyToken: "k", modifierFlags: [.command, .shift]),
            for: .exportConnections
        )

        let reloaded = AppKeyboardShortcutStore(userDefaults: defaults, storageKey: storageKey)
        #expect(reloaded.shortcut(for: .importConnections) == nil)
        #expect(reloaded.shortcut(for: .exportConnections)?.displayText == "⌘⇧K")
    }

    @Test
    func detectsConflictingShortcuts() {
        let store = makeStore()
        store.setShortcut(
            AppKeyboardShortcut(keyToken: "i", modifierFlags: [.command]),
            for: .exportConnections
        )

        #expect(store.conflicts.count == 1)
        let conflict = store.conflicts.first
        #expect(conflict?.shortcut.displayText == "⌘I")
        #expect(conflict?.commands.contains(.importConnections) == true)
        #expect(conflict?.commands.contains(.exportConnections) == true)
    }

    @Test
    func rejectsShortcutsWithoutPrimaryModifier() {
        let shortcut = AppKeyboardShortcut(keyToken: "a", modifierFlags: [.shift])
        #expect(!shortcut.isUsable)
    }

    private func makeStore() -> AppKeyboardShortcutStore {
        let suiteName = "remora-shortcuts-tests-\(UUID().uuidString)"
        let storageKey = "shortcuts-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppKeyboardShortcutStore(userDefaults: defaults, storageKey: storageKey)
    }
}
