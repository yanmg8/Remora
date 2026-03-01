import SwiftUI
import RemoraCore

struct RemoteFilePropertiesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RemoteFilePropertiesViewModel

    init(path: String, fileTransfer: FileTransferViewModel, initialAttributes: RemoteFileAttributes? = nil) {
        _viewModel = StateObject(
            wrappedValue: RemoteFilePropertiesViewModel(
                path: path,
                fileTransfer: fileTransfer,
                initialAttributes: initialAttributes
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File Properties")
                .font(.headline)

            Text(viewModel.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Permissions")
                    TextField("755", text: $viewModel.permissionsText)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }
                GridRow {
                    Text("Date")
                    Text(viewModel.modifiedAtDisplayText)
                        .font(.caption.monospaced())
                }
                GridRow {
                    Text("Size")
                    Text(viewModel.sizeDisplayText)
                        .font(.caption.monospaced())
                }
            }

            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Save") {
                    Task { await viewModel.save() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading || viewModel.isSaving)
            }
        }
        .padding(16)
        .frame(width: 460)
        .task {
            await viewModel.load()
        }
    }
}
