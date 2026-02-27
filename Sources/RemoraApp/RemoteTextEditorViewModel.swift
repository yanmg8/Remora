import Foundation

@MainActor
final class RemoteTextEditorViewModel: ObservableObject {
    @Published var text: String = ""
    @Published private(set) var encodingLabel: String = "UTF-8"
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var isReadOnly = false
    @Published var errorMessage: String?

    let path: String

    private let fileTransfer: FileTransferViewModel
    private var baselineText: String = ""
    private var expectedModifiedAt: Date?

    init(path: String, fileTransfer: FileTransferViewModel) {
        self.path = path
        self.fileTransfer = fileTransfer
    }

    var hasUnsavedChanges: Bool {
        text != baselineText
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let doc = try await fileTransfer.loadTextDocument(path: path)
            text = doc.text
            baselineText = doc.text
            encodingLabel = doc.encoding
            expectedModifiedAt = doc.modifiedAt
            isReadOnly = doc.isReadOnly
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard !isReadOnly else {
            errorMessage = "This file is opened as read-only due to size limits."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            expectedModifiedAt = try await fileTransfer.saveTextDocument(
                path: path,
                text: text,
                expectedModifiedAt: expectedModifiedAt
            )
            baselineText = text
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
