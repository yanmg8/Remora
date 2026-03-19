import Foundation
import RemoraCore

struct PermissionTriadState: Equatable {
    var read: Bool
    var write: Bool
    var execute: Bool

    init(read: Bool = false, write: Bool = false, execute: Bool = false) {
        self.read = read
        self.write = write
        self.execute = execute
    }

    var octalDigit: UInt16 {
        (read ? 4 : 0) + (write ? 2 : 0) + (execute ? 1 : 0)
    }

    init(octalDigit: UInt16) {
        self.read = (octalDigit & 0b100) != 0
        self.write = (octalDigit & 0b010) != 0
        self.execute = (octalDigit & 0b001) != 0
    }
}

enum RemotePermissionScope {
    case owner
    case group
    case other
}

enum RemotePermissionKind {
    case read
    case write
    case execute
}

struct RemotePermissionBits: Equatable {
    var owner: PermissionTriadState
    var group: PermissionTriadState
    var other: PermissionTriadState

    init(mode: UInt16) {
        owner = PermissionTriadState(octalDigit: (mode >> 6) & 0b111)
        group = PermissionTriadState(octalDigit: (mode >> 3) & 0b111)
        other = PermissionTriadState(octalDigit: mode & 0b111)
    }

    init?(octalText: String) {
        let trimmed = octalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.hasPrefix("0") ? String(trimmed.dropFirst()) : trimmed
        guard normalized.count == 3,
              normalized.allSatisfy({ $0 >= "0" && $0 <= "7" }),
              let mode = UInt16(normalized, radix: 8)
        else {
            return nil
        }

        self.init(mode: mode)
    }

    var mode: UInt16 {
        (owner.octalDigit << 6) | (group.octalDigit << 3) | other.octalDigit
    }

    var octalText: String {
        String(format: "%04o", mode)
    }

    mutating func set(scope: RemotePermissionScope, permission: RemotePermissionKind, enabled: Bool) {
        switch scope {
        case .owner:
            var triad = owner
            update(permission: permission, enabled: enabled, triad: &triad)
            owner = triad
        case .group:
            var triad = group
            update(permission: permission, enabled: enabled, triad: &triad)
            group = triad
        case .other:
            var triad = other
            update(permission: permission, enabled: enabled, triad: &triad)
            other = triad
        }
    }

    private func update(permission: RemotePermissionKind, enabled: Bool, triad: inout PermissionTriadState) {
        switch permission {
        case .read:
            triad.read = enabled
        case .write:
            triad.write = enabled
        case .execute:
            triad.execute = enabled
        }
    }
}

@MainActor
final class RemotePermissionsEditorViewModel: ObservableObject {
    @Published var permissionsText: String = "0000"
    @Published var ownerText: String = ""
    @Published var groupText: String = ""
    @Published var applyRecursively = false
    @Published private(set) var ownerPermissions = PermissionTriadState()
    @Published private(set) var groupPermissions = PermissionTriadState()
    @Published private(set) var otherPermissions = PermissionTriadState()
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var isDirectory = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let path: String

    private let fileTransfer: FileTransferViewModel
    private let initialAttributes: RemoteFileAttributes?
    private var permissionBits = RemotePermissionBits(mode: 0)

    init(path: String, fileTransfer: FileTransferViewModel, initialAttributes: RemoteFileAttributes? = nil) {
        self.path = path
        self.fileTransfer = fileTransfer
        self.initialAttributes = initialAttributes
        if let initialAttributes {
            apply(attributes: initialAttributes)
        }
    }

    func load() async {
        if let initialAttributes {
            errorMessage = nil
            if initialAttributes.permissions != nil, initialAttributes.owner != nil, initialAttributes.group != nil {
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let attributes = try await fileTransfer.loadRemoteAttributes(path: path)
            apply(attributes: attributes)
            errorMessage = nil
            successMessage = nil
        } catch {
            if initialAttributes == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setPermission(scope: RemotePermissionScope, permission: RemotePermissionKind, enabled: Bool) {
        permissionBits.set(scope: scope, permission: permission, enabled: enabled)
        syncPublishedPermissionState()
        permissionsText = permissionBits.octalText
    }

    func updatePermissionsText(_ text: String) {
        permissionsText = text
        guard let parsed = RemotePermissionBits(octalText: text) else { return }
        permissionBits = parsed
        syncPublishedPermissionState()
    }

    func save() async {
        guard let parsed = RemotePermissionBits(octalText: permissionsText) else {
            errorMessage = tr("Permissions should be a valid octal value, e.g. 0755")
            return
        }

        isSaving = true
        defer { isSaving = false }
        permissionBits = parsed
        syncPublishedPermissionState()

        let trimmedOwner = ownerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGroup = groupText.trimmingCharacters(in: .whitespacesAndNewlines)

        let attributes = RemoteFileAttributes(
            permissions: parsed.mode,
            owner: trimmedOwner.isEmpty ? nil : trimmedOwner,
            group: trimmedGroup.isEmpty ? nil : trimmedGroup,
            size: 0,
            modifiedAt: Date(),
            isDirectory: isDirectory
        )

        do {
            try await fileTransfer.saveRemoteAttributes(path: path, attributes: attributes, recursively: applyRecursively)
            errorMessage = nil
            successMessage = tr("Saved")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(attributes: RemoteFileAttributes) {
        permissionBits = RemotePermissionBits(mode: attributes.permissions ?? 0)
        syncPublishedPermissionState()
        permissionsText = permissionBits.octalText
        ownerText = attributes.owner ?? ""
        groupText = attributes.group ?? ""
        isDirectory = attributes.isDirectory
    }

    private func syncPublishedPermissionState() {
        ownerPermissions = permissionBits.owner
        groupPermissions = permissionBits.group
        otherPermissions = permissionBits.other
    }
}
