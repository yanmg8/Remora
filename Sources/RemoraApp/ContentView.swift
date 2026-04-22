import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import RemoraCore

@MainActor
struct ContentView: View {
    enum SidebarFocusedField: Hashable {
        case hostSearch
    }

    @Environment(\.openWindow) var openWindow
    @Environment(\.openURL) var openURL
    @StateObject var workspace = WorkspaceViewModel()
    @StateObject var hostCatalog = HostCatalogStore()
    

    @State var hostSearchQuery = ""
    @FocusState var sidebarFocusedField: SidebarFocusedField?
    @State var hasClearedInitialSidebarSearchFocus = false
    @State var selectedHostID: UUID?
    @State var selectedTemplateID: UUID?
    @State var splitVisibility: NavigationSplitViewVisibility = .all
    @State var splitVisibilityBeforeFocusMode: NavigationSplitViewVisibility?
    @State var workspaceFocusMode: WorkspaceFocusMode = .none
    @State var collapsedGroupNames: Set<String> = []
    @State var isGroupEditorSheetPresented = false
    @State var groupEditorMode: SidebarGroupEditorMode = .create
    @State var groupEditorSourceName = ""
    @State var groupEditorDraft = ""
    @State var isHostEditorSheetPresented = false
    @State var hostEditorMode: SidebarHostEditorMode = .create
    @State var hostEditorDraft = SidebarHostEditorDraft()
    @State var hostEditorTestState: HostConnectionTestState = .idle
    @State var isExportSheetPresented = false
    @State var exportDraft = HostExportDraft()
    @State var isPasswordExportWarningPresented = false
    @State var isConnectionInfoPasswordWarningPresented = false
    @State var pendingConnectionInfoPasswordCopyHost: RemoraCore.Host?
    @State var pendingHostDeletion: PendingHostDeletion?
    @State var pendingGroupDeletion: PendingGroupDeletion?
    @State var isExportingHosts = false
    @State var isImportingHosts = false
    @State var isImportSourceSheetPresented = false
    @State var isExportResultAlertPresented = false
    @State var exportAlertTitle = ""
    @State var exportAlertMessage = ""
    @State var isImportProgressSheetPresented = false
    @State var importSource = HostConnectionImportSource.remoraJSONCSV
    @State var importSourceFilename = ""
    @State var importProgress = HostConnectionImportProgress(phase: tr("Preparing"), completed: 0, total: 1)
    @State var importResultMessage: String?
    @State var importErrorMessage: String?
    @State var isRenameSessionSheetPresented = false
    @State var renameSessionID: UUID?
    @State var renameSessionDraft = ""
    @State var quickCommandEditorHostID: UUID?
    @State var quickCommandEditingID: UUID?
    @State var quickCommandNameDraft = ""
    @State var quickCommandBodyDraft = ""
    @State var quickCommandValidationMessage: String?
    @State var quickPathEditorHostID: UUID?
    @State var quickPathEditingID: UUID?
    @State var quickPathNameDraft = ""
    @State var quickPathValueDraft = ""
    @State var quickPathValidationMessage: String?
    @RemoraStored(\.connectionInfoPasswordCopyMutedUntilEpoch)
    var connectionInfoPasswordCopyMutedUntilEpoch: Double
    @RemoraStored(\.connectionInfoPasswordCopyMuteForever)
    var connectionInfoPasswordCopyMuteForever: Bool

    var selectedHost: RemoraCore.Host? {
        hostCatalog.host(id: selectedHostID)
    }

    var connectionInfoPasswordCopyMutedUntil: Date? {
        guard connectionInfoPasswordCopyMutedUntilEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: connectionInfoPasswordCopyMutedUntilEpoch)
    }

    var quickCommandEditorHost: RemoraCore.Host? {
        hostCatalog.host(id: quickCommandEditorHostID)
    }

    var quickPathEditorHost: RemoraCore.Host? {
        hostCatalog.host(id: quickPathEditorHostID)
    }

    var quickCommandEditorBinding: Binding<Bool> {
        Binding(
            get: { quickCommandEditorHostID != nil },
            set: { isPresented in
                if !isPresented {
                    dismissQuickCommandEditor()
                }
            }
        )
    }

    var quickPathEditorBinding: Binding<Bool> {
        Binding(
            get: { quickPathEditorHostID != nil },
            set: { isPresented in
                if !isPresented {
                    dismissQuickPathEditor()
                }
            }
        )
    }

    var availableTemplates: [HostSessionTemplate] {
        hostCatalog.templates(for: selectedHostID)
    }

    var selectedTemplate: HostSessionTemplate? {
        guard let selectedTemplateID else { return nil }
        return availableTemplates.first(where: { $0.id == selectedTemplateID })
    }

    var isHostDeletionConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingHostDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingHostDeletion = nil
                }
            }
        )
    }

    var visibleGroupSections: [HostGroupSection] {
        hostCatalog.groupSections(matching: hostSearchQuery)
    }

    var visibleUngroupedHosts: [RemoraCore.Host] {
        hostCatalog.ungroupedHosts(matching: hostSearchQuery)
    }

    var groupDeletionSheetBinding: Binding<Bool> {
        Binding(
            get: { pendingGroupDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingGroupDeletion = nil
                }
            }
        )
    }

    var activeRuntimeConnectionStatePublisher: AnyPublisher<ActiveRuntimeConnectionState, Never> {
        guard let runtime = workspace.activePane?.runtime else {
            return Just(
                ActiveRuntimeConnectionState(
                    runtimeID: nil,
                    connectionMode: nil,
                    connectionState: "Disconnected"
                )
            )
            .eraseToAnyPublisher()
        }

        return Publishers.CombineLatest3(
            runtime.$connectionMode,
            runtime.$connectionState,
            runtime.$connectedSSHHost
        )
        .map { mode, state, _ in
            ActiveRuntimeConnectionState(
                runtimeID: ObjectIdentifier(runtime),
                connectionMode: mode,
                connectionState: state
            )
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var body: some View {
        let rootContent = ZStack {
            backgroundGradient

            NavigationSplitView(columnVisibility: $splitVisibility) {
                sidebar
            } detail: {
                detailWorkspace
            }
            .navigationSplitViewStyle(.balanced)
        }
        .frame(minWidth: 1200, minHeight: 760)

        let lifecycleContent = rootContent
            .onAppear {
                if selectedHostID == nil {
                    selectedHostID = hostCatalog.hosts.first?.id
                }
                if !hasClearedInitialSidebarSearchFocus {
                    hasClearedInitialSidebarSearchFocus = true
                    sidebarFocusedField = nil
                    DispatchQueue.main.async {
                        sidebarFocusedField = nil
                    }
                }
                if let firstPane = workspace.activePane {
                    firstPane.runtime.connectLocalShell()
                }
            }
            .onChange(of: selectedHostID) {
                selectedTemplateID = availableTemplates.first?.id
            }
            .onChange(of: workspace.activeTabID) {
                normalizeWorkspaceFocusMode()
            }
            .onChange(of: workspace.activePaneByTab) {
                normalizeWorkspaceFocusMode()
            }
            .onChange(of: splitVisibility) {
                normalizeWorkspaceFocusMode()
            }

        let commandContent = lifecycleContent
            .onReceive(NotificationCenter.default.publisher(for: .remoraOpenSettingsCommand)) { _ in
                openWindow(id: "settings")
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoraToggleSidebarCommand)) { _ in
                toggleSSHSidebarVisibility()
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoraNewSSHConnectionCommand)) { _ in
                beginCreateHostInPreferredGroup()
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoraImportConnectionsCommand)) { _ in
                guard !isExportingHosts, !isImportingHosts, !hostCatalog.isLoading else { return }
                beginImportHosts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoraExportConnectionsCommand)) { _ in
                guard !isExportingHosts, !isImportingHosts, !hostCatalog.isLoading else { return }
                beginExportAllHosts()
            }

        let syncedContent = commandContent
            .onReceive(activeRuntimeConnectionStatePublisher) { _ in
                normalizeWorkspaceFocusMode()
            }
            .onChange(of: hostCatalog.hosts) {
                if let selectedHostID, hostCatalog.host(id: selectedHostID) != nil {
                    return
                }
                selectedHostID = hostCatalog.hosts.first?.id
                selectedTemplateID = availableTemplates.first?.id
            }
            .onChange(of: hostCatalog.groups) {
                collapsedGroupNames = collapsedGroupNames.intersection(Set(hostCatalog.groups))
            }

        return syncedContent
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: workspace.activeTabID)
            .animation(.spring(response: 0.26, dampingFraction: 0.86), value: workspaceFocusMode)
            .onExitCommand {
                guard workspaceFocusMode.isActive else { return }
                exitWorkspaceFocusMode()
            }
            .task {
                await UpdateChecker.shared.performAutomaticCheckIfNeeded()
            }
    }


}
