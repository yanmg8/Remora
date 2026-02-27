import SwiftUI
import RemoraCore

struct FileManagerPanelView: View {
    @ObservedObject var viewModel: FileTransferViewModel

    @State private var selectedLocalID: UUID?
    @State private var selectedRemotePath: String?
    @State private var hoveredLocalID: UUID?
    @State private var hoveredRemotePath: String?
    @State private var hoveredTransferID: UUID?

    private var selectedLocalEntry: LocalFileEntry? {
        viewModel.localEntries.first(where: { $0.id == selectedLocalID })
    }

    private var selectedRemoteEntry: RemoteFileEntry? {
        guard let selectedRemotePath else { return nil }
        return viewModel.remoteEntries.first(where: { $0.path == selectedRemotePath })
    }

    var body: some View {
        GroupBox {
            VStack(spacing: 10) {
                HStack {
                    Label("File Manager", systemImage: "folder.badge.gearshape")
                        .panelTitleStyle()
                    Spacer()
                    Button("Refresh") {
                        viewModel.refreshAll()
                    }
                    .buttonStyle(.bordered)
                }

                HSplitView {
                    localPanel
                    remotePanel
                }
                .frame(minHeight: 250)

                HStack {
                    Button {
                        if let selectedLocalEntry {
                            viewModel.enqueueUpload(localEntry: selectedLocalEntry)
                        }
                    } label: {
                        Label("Upload", systemImage: "arrow.up.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedLocalEntry == nil || selectedLocalEntry?.isDirectory == true)

                    Button {
                        if let selectedRemoteEntry {
                            viewModel.enqueueDownload(remoteEntry: selectedRemoteEntry)
                        }
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedRemoteEntry == nil || selectedRemoteEntry?.isDirectory == true)

                    Spacer()
                }

                transferQueuePanel
            }
        }
        .glassCard()
        .animation(.easeInOut(duration: 0.2), value: viewModel.transferQueue.map(\.status))
    }

    private var localPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Local", systemImage: "internaldrive")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Up") {
                    viewModel.goUpLocalDirectory()
                }
                .buttonStyle(.bordered)
            }

            Text(viewModel.localDirectoryURL.path)
                .monoMetaStyle()
                .lineLimit(1)

            List(viewModel.localEntries, id: \.id) { entry in
                Button {
                    if entry.isDirectory {
                        viewModel.openLocal(entry)
                        selectedLocalID = nil
                    } else {
                        selectedLocalID = entry.id
                    }
                } label: {
                    HStack {
                        Image(systemName: entry.isDirectory ? "folder" : "doc")
                        Text(entry.name)
                            .lineLimit(1)
                            .foregroundStyle(VisualStyle.textPrimary)
                        Spacer()
                        if !entry.isDirectory {
                            Text("\(entry.size)")
                                .font(.caption.monospaced())
                                .foregroundStyle(VisualStyle.textSecondary)
                        }
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedLocalID == entry.id || hoveredLocalID == entry.id ? VisualStyle.leftInteractiveBackground : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredLocalID = hovering ? entry.id : nil
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scrollContentBackground(.hidden)
            .background(VisualStyle.rightPanelBackground)
        }
    }

    private var remotePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Remote", systemImage: "externaldrive")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Up") {
                    viewModel.goUpRemoteDirectory()
                }
                .buttonStyle(.bordered)
            }

            Text(viewModel.remoteDirectoryPath)
                .monoMetaStyle()
                .lineLimit(1)

            List(viewModel.remoteEntries, id: \.path) { entry in
                Button {
                    if entry.isDirectory {
                        viewModel.openRemote(entry)
                        selectedRemotePath = nil
                    } else {
                        selectedRemotePath = entry.path
                    }
                } label: {
                    HStack {
                        Image(systemName: entry.isDirectory ? "folder" : "doc")
                        Text(entry.name)
                            .lineLimit(1)
                            .foregroundStyle(VisualStyle.textPrimary)
                        Spacer()
                        if !entry.isDirectory {
                            Text("\(entry.size)")
                                .font(.caption.monospaced())
                                .foregroundStyle(VisualStyle.textSecondary)
                        }
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedRemotePath == entry.path || hoveredRemotePath == entry.path ? VisualStyle.leftInteractiveBackground : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredRemotePath = hovering ? entry.path : nil
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scrollContentBackground(.hidden)
            .background(VisualStyle.rightPanelBackground)
        }
    }

    private var transferQueuePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Transfer Queue")
                .font(.subheadline.weight(.semibold))

            if viewModel.transferQueue.isEmpty {
                Text("No transfer tasks")
                    .monoMetaStyle()
            } else {
                List(viewModel.transferQueue) { item in
                    HStack(spacing: 8) {
                        Text(item.direction.rawValue)
                            .font(.caption.monospaced())
                            .frame(width: 70, alignment: .leading)
                            .foregroundStyle(VisualStyle.textSecondary)
                        Text(item.name)
                            .lineLimit(1)
                            .foregroundStyle(VisualStyle.textPrimary)
                        Spacer()
                        Text(item.status.rawValue)
                            .font(.caption.monospaced())
                            .foregroundStyle(statusColor(item.status))
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(hoveredTransferID == item.id ? VisualStyle.leftInteractiveBackground : Color.clear)
                    )
                    .onHover { hovering in
                        hoveredTransferID = hovering ? item.id : nil
                    }
                }
                .frame(minHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .scrollContentBackground(.hidden)
                .background(VisualStyle.rightPanelBackground)
            }
        }
    }

    private func statusColor(_ status: TransferStatus) -> Color {
        switch status {
        case .queued:
            return .secondary
        case .running:
            return .orange
        case .success:
            return .green
        case .failed:
            return .red
        }
    }
}
