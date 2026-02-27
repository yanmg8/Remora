import Foundation

public enum HostKeyValidationResult: Equatable, Sendable {
    case trusted
    case firstSeen
    case changed(old: String, new: String)
}

public actor HostKeyStore {
    private var fingerprints: [String: String] = [:]

    public init() {}

    public func validate(host: String, fingerprint: String) -> HostKeyValidationResult {
        if let existing = fingerprints[host] {
            if existing == fingerprint {
                return .trusted
            }
            return .changed(old: existing, new: fingerprint)
        }

        fingerprints[host] = fingerprint
        return .firstSeen
    }

    public func trust(host: String, fingerprint: String) {
        fingerprints[host] = fingerprint
    }
}
