import AppKit
import ApplicationServices
import Foundation
import Testing

@MainActor
struct RemoraUIAutomationTests {
    @Test
    func fileManagerHeaderTogglesExpandAndCollapse() throws {
        guard ProcessInfo.processInfo.environment["REMORA_RUN_UI_TESTS"] == "1" else {
            return
        }

        #expect(AXIsProcessTrusted(), "Grant Accessibility permission to the terminal running tests.")
        guard AXIsProcessTrusted() else { return }

        let appURL = try locateRemoraAppBinary()
        let process = Process()
        process.executableURL = appURL
        process.arguments = []
        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
            }
        }

        guard waitUntil(timeout: 8, {
            NSRunningApplication(processIdentifier: process.processIdentifier) != nil
        }) else {
            Issue.record("RemoraApp did not launch in time.")
            return
        }

        NSRunningApplication(processIdentifier: process.processIdentifier)?
            .activate()

        let appElement = AXUIElementCreateApplication(process.processIdentifier)

        guard let fileManagerButton = waitForElement(
            in: appElement,
            timeout: 8,
            matching: { element in
                role(of: element) == kAXButtonRole as String && title(of: element) == "File Manager"
            }
        ) else {
            Issue.record("Could not find File Manager header button.")
            return
        }

        #expect(findElement(in: appElement, matching: { title(of: $0) == "Refresh" }) == nil)

        _ = AXUIElementPerformAction(fileManagerButton, kAXPressAction as CFString)

        let expanded = waitUntil(timeout: 5, {
            findElement(in: appElement, matching: { title(of: $0) == "Refresh" }) != nil
        })
        #expect(expanded, "File Manager should expand and show Refresh button.")

        _ = AXUIElementPerformAction(fileManagerButton, kAXPressAction as CFString)

        let collapsed = waitUntil(timeout: 5, {
            findElement(in: appElement, matching: { title(of: $0) == "Refresh" }) == nil
        })
        #expect(collapsed, "File Manager should collapse and hide Refresh button.")
    }

    @Test
    func sidebarGroupTogglesThreadsVisibility() throws {
        guard ProcessInfo.processInfo.environment["REMORA_RUN_UI_TESTS"] == "1" else {
            return
        }

        #expect(AXIsProcessTrusted(), "Grant Accessibility permission to the terminal running tests.")
        guard AXIsProcessTrusted() else { return }

        let appURL = try locateRemoraAppBinary()
        let process = Process()
        process.executableURL = appURL
        process.arguments = []
        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
            }
        }

        guard waitUntil(timeout: 8, {
            NSRunningApplication(processIdentifier: process.processIdentifier) != nil
        }) else {
            Issue.record("RemoraApp did not launch in time.")
            return
        }

        NSRunningApplication(processIdentifier: process.processIdentifier)?
            .activate()

        let appElement = AXUIElementCreateApplication(process.processIdentifier)

        guard let groupHeaderButton = waitForElement(
            in: appElement,
            timeout: 8,
            matching: { element in
                role(of: element) == kAXButtonRole as String && title(of: element) == "Production"
            }
        ) else {
            Issue.record("Could not find 'Production' group header button.")
            return
        }

        let hostVisibleInitially = waitUntil(timeout: 5, {
            findElement(in: appElement, matching: { title(of: $0) == "prod-api" }) != nil
        })
        #expect(hostVisibleInitially, "Expected prod-api row to be visible before collapsing group.")

        _ = AXUIElementPerformAction(groupHeaderButton, kAXPressAction as CFString)

        let hostHiddenAfterCollapse = waitUntil(timeout: 5, {
            findElement(in: appElement, matching: { title(of: $0) == "prod-api" }) == nil
        })
        #expect(hostHiddenAfterCollapse, "Expected prod-api row to be hidden after collapsing group.")

        _ = AXUIElementPerformAction(groupHeaderButton, kAXPressAction as CFString)

        let hostVisibleAfterExpand = waitUntil(timeout: 5, {
            findElement(in: appElement, matching: { title(of: $0) == "prod-api" }) != nil
        })
        #expect(hostVisibleAfterExpand, "Expected prod-api row to be visible after expanding group.")
    }

    private func locateRemoraAppBinary() throws -> URL {
        if let custom = ProcessInfo.processInfo.environment["REMORA_APP_BINARY"], !custom.isEmpty {
            let url = URL(fileURLWithPath: custom)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            root.appendingPathComponent(".build/debug/RemoraApp"),
            root.appendingPathComponent(".build/arm64-apple-macosx/debug/RemoraApp"),
            root.appendingPathComponent(".build/x86_64-apple-macosx/debug/RemoraApp"),
        ]

        if let hit = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return hit
        }

        throw NSError(
            domain: "RemoraUIAutomationTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Cannot locate RemoraApp binary. Set REMORA_APP_BINARY to the app executable path."]
        )
    }

    private func waitForElement(
        in appElement: AXUIElement,
        timeout: TimeInterval,
        matching: (AXUIElement) -> Bool
    ) -> AXUIElement? {
        var found: AXUIElement?
        let ok = waitUntil(timeout: timeout) {
            found = findElement(in: appElement, matching: matching)
            return found != nil
        }
        return ok ? found : nil
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    private func findElement(
        in root: AXUIElement,
        matching: (AXUIElement) -> Bool
    ) -> AXUIElement? {
        if matching(root) { return root }
        for child in children(of: root) {
            if let found = findElement(in: child, matching: matching) {
                return found
            }
        }
        return nil
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard status == .success, let raw = value else { return [] }
        return raw as? [AXUIElement] ?? []
    }

    private func title(of element: AXUIElement) -> String? {
        stringAttribute(kAXTitleAttribute as CFString, of: element)
            ?? stringAttribute(kAXDescriptionAttribute as CFString, of: element)
            ?? stringAttribute(kAXValueAttribute as CFString, of: element)
    }

    private func role(of element: AXUIElement) -> String? {
        stringAttribute(kAXRoleAttribute as CFString, of: element)
    }

    private func stringAttribute(_ attr: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attr, &value)
        guard status == .success, let raw = value else { return nil }
        return raw as? String
    }
}
