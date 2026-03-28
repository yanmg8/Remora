import AppKit
import SwiftUI
import Testing
@testable import RemoraApp

@Suite(.serialized)
@MainActor
struct SidebarHeaderButtonsTests {
    @Test
    func buttonKindsUseStableDistinctMetadata() {
        #expect(SidebarThreadsHeaderButtonKind.allCases.count == 2)
        #expect(
            SidebarThreadsHeaderButtonKind.createConnection.systemImage !=
            SidebarThreadsHeaderButtonKind.createGroup.systemImage
        )
        #expect(SidebarThreadsHeaderButtonKind.createConnection.accessibilityIdentifier == "sidebar-header-create-connection")
        #expect(SidebarThreadsHeaderButtonKind.createGroup.accessibilityIdentifier == "sidebar-header-create-group")
    }

    @Test
    func actionsRouteConnectionAndGroupButtonsIndependently() {
        var createConnectionCount = 0
        var createGroupCount = 0

        let actions = SidebarThreadsHeaderActions(
            onCreateConnection: {
                createConnectionCount += 1
            },
            onCreateGroup: {
                createGroupCount += 1
            }
        )

        actions.perform(.createConnection)
        actions.perform(.createGroup)

        #expect(createConnectionCount == 1)
        #expect(createGroupCount == 1)
    }

    @Test
    func headerRendersInLightAndDarkAppearances() {
        assertHeaderRendering(for: .light)
        assertHeaderRendering(for: .dark)
    }

    private func assertHeaderRendering(for colorScheme: ColorScheme) {
        let host = NSHostingView(
            rootView: SidebarThreadsHeaderView(
                actions: SidebarThreadsHeaderActions(
                    onCreateConnection: {},
                    onCreateGroup: {}
                )
            )
            .environment(\.colorScheme, colorScheme)
        )
        host.frame = NSRect(x: 0, y: 0, width: 260, height: 32)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        let imageRep = host.bitmapImageRepForCachingDisplay(in: host.bounds)
        #expect(imageRep != nil, "Sidebar header should render a cached image in \(String(describing: colorScheme)) mode.")
        if let imageRep {
            host.cacheDisplay(in: host.bounds, to: imageRep)
            #expect(imageRep.pixelsWide > 0)
            #expect(imageRep.pixelsHigh > 0)
        }
        #expect(host.fittingSize.width >= 120)
        #expect(host.fittingSize.height >= 20)
    }
}
