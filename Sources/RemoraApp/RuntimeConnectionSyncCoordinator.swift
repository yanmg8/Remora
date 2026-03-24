import Foundation

@MainActor
enum RuntimeConnectionSyncCoordinator {
    static func bindRuntimeDrivenServices(
        fileTransfer: FileTransferViewModel,
        directorySyncBridge: TerminalDirectorySyncBridge,
        activeRuntime: TerminalRuntime?,
        syncFileManagerBinding: () -> Void,
        syncServerMetricsTracking: () -> Void
    ) {
        directorySyncBridge.bind(fileTransfer: fileTransfer, runtime: activeRuntime)
        syncRuntimeDrivenServices(
            syncFileManagerBinding: syncFileManagerBinding,
            syncServerMetricsTracking: syncServerMetricsTracking
        )
    }

    static func attachActiveRuntime(
        _ activeRuntime: TerminalRuntime?,
        directorySyncBridge: TerminalDirectorySyncBridge,
        syncFileManagerBinding: () -> Void,
        syncServerMetricsTracking: () -> Void
    ) {
        directorySyncBridge.attachRuntime(activeRuntime)
        syncRuntimeDrivenServices(
            syncFileManagerBinding: syncFileManagerBinding,
            syncServerMetricsTracking: syncServerMetricsTracking
        )
    }

    static func syncRuntimeDrivenServices(
        syncFileManagerBinding: () -> Void,
        syncServerMetricsTracking: () -> Void
    ) {
        syncFileManagerBinding()
        syncServerMetricsTracking()
    }

    static func syncMetricsTracking(_ syncServerMetricsTracking: () -> Void) {
        syncServerMetricsTracking()
    }
}
