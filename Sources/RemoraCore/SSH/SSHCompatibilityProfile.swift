import Foundation

enum SSHCompatibilityKexAlgorithm: String, Codable, Equatable, Sendable {
    case diffieHellmanGroup14SHA1 = "diffie-hellman-group14-sha1"
    case diffieHellmanGroup1SHA1 = "diffie-hellman-group1-sha1"
}

enum SSHCompatibilityHostKeyAlgorithm: String, Codable, Equatable, Sendable {
    case sshRSA = "ssh-rsa"
    case sshDSS = "ssh-dss"
}

enum SSHCompatibilityPubkeyAlgorithm: String, Codable, Equatable, Sendable {
    case sshRSA = "ssh-rsa"
}

struct SSHCompatibilityProfile: Codable, Equatable, Sendable {
    var kexAlgorithms: [SSHCompatibilityKexAlgorithm]
    var hostKeyAlgorithms: [SSHCompatibilityHostKeyAlgorithm]
    var pubkeyAcceptedAlgorithms: [SSHCompatibilityPubkeyAlgorithm]

    init(
        kexAlgorithms: [SSHCompatibilityKexAlgorithm] = [],
        hostKeyAlgorithms: [SSHCompatibilityHostKeyAlgorithm] = [],
        pubkeyAcceptedAlgorithms: [SSHCompatibilityPubkeyAlgorithm] = []
    ) {
        self.kexAlgorithms = Self.unique(kexAlgorithms)
        self.hostKeyAlgorithms = Self.unique(hostKeyAlgorithms)
        self.pubkeyAcceptedAlgorithms = Self.unique(pubkeyAcceptedAlgorithms)
    }

    var isDefault: Bool {
        kexAlgorithms.isEmpty && hostKeyAlgorithms.isEmpty && pubkeyAcceptedAlgorithms.isEmpty
    }

    func appendingKex(_ algorithm: SSHCompatibilityKexAlgorithm) -> SSHCompatibilityProfile {
        SSHCompatibilityProfile(
            kexAlgorithms: kexAlgorithms + [algorithm],
            hostKeyAlgorithms: hostKeyAlgorithms,
            pubkeyAcceptedAlgorithms: pubkeyAcceptedAlgorithms
        )
    }

    func appendingHostKey(_ algorithm: SSHCompatibilityHostKeyAlgorithm) -> SSHCompatibilityProfile {
        SSHCompatibilityProfile(
            kexAlgorithms: kexAlgorithms,
            hostKeyAlgorithms: hostKeyAlgorithms + [algorithm],
            pubkeyAcceptedAlgorithms: pubkeyAcceptedAlgorithms
        )
    }

    func appendingPubkeyAccepted(_ algorithm: SSHCompatibilityPubkeyAlgorithm) -> SSHCompatibilityProfile {
        SSHCompatibilityProfile(
            kexAlgorithms: kexAlgorithms,
            hostKeyAlgorithms: hostKeyAlgorithms,
            pubkeyAcceptedAlgorithms: pubkeyAcceptedAlgorithms + [algorithm]
        )
    }

    func additionalSSHOptions() -> [String] {
        var options: [String] = []
        if !kexAlgorithms.isEmpty {
            options.append(contentsOf: ["-o", "KexAlgorithms=+\(kexAlgorithms.map(\.rawValue).joined(separator: ","))"])
        }
        if !hostKeyAlgorithms.isEmpty {
            options.append(contentsOf: ["-o", "HostKeyAlgorithms=+\(hostKeyAlgorithms.map(\.rawValue).joined(separator: ","))"])
        }
        if !pubkeyAcceptedAlgorithms.isEmpty {
            options.append(contentsOf: ["-o", "PubkeyAcceptedAlgorithms=+\(pubkeyAcceptedAlgorithms.map(\.rawValue).joined(separator: ","))"])
        }
        return options
    }

    private static func unique<Value: Hashable>(_ values: [Value]) -> [Value] {
        var seen = Set<Value>()
        return values.filter { seen.insert($0).inserted }
    }
}

struct SSHCompatibilityRecord: Codable, Equatable, Sendable {
    var host: String
    var port: Int
    var fingerprint: String?
    var profile: SSHCompatibilityProfile
    var firstDetectedAt: Date
    var lastSucceededAt: Date
}

actor SSHCompatibilityProfileStore {
    static let shared = SSHCompatibilityProfileStore()

    private let fileStore: RemoraJSONFileStore<[String: SSHCompatibilityRecord]>
    private var cachedRecords: [String: SSHCompatibilityRecord] = [:]
    private var hasLoaded = false

    init(baseDirectoryURL: URL = RemoraConfigPaths.rootDirectoryURL()) {
        self.fileStore = RemoraJSONFileStore(
            fileURL: baseDirectoryURL.appendingPathComponent(RemoraConfigFile.sshCompatibilityProfiles.rawValue, isDirectory: false)
        )
    }

    func cachedProfile(for host: Host) -> SSHCompatibilityProfile? {
        ensureLoadedIfNeeded()
        return cachedRecords[cacheKey(for: host)]?.profile
    }

    func cachedRecord(for host: Host) -> SSHCompatibilityRecord? {
        ensureLoadedIfNeeded()
        return cachedRecords[cacheKey(for: host)]
    }

    func recordSuccess(profile: SSHCompatibilityProfile, for host: Host, fingerprint: String?) {
        ensureLoadedIfNeeded()
        let key = cacheKey(for: host)

        guard !profile.isDefault else {
            cachedRecords.removeValue(forKey: key)
            persist()
            return
        }

        let now = Date()
        if var existing = cachedRecords[key] {
            existing.profile = profile
            existing.lastSucceededAt = now
            existing.fingerprint = fingerprint ?? existing.fingerprint
            cachedRecords[key] = existing
        } else {
            cachedRecords[key] = SSHCompatibilityRecord(
                host: normalizedHost(host.address),
                port: host.port,
                fingerprint: fingerprint,
                profile: profile,
                firstDetectedAt: now,
                lastSucceededAt: now
            )
        }
        persist()
    }

    func clear(for host: Host) {
        ensureLoadedIfNeeded()
        cachedRecords.removeValue(forKey: cacheKey(for: host))
        persist()
    }

    private func ensureLoadedIfNeeded() {
        guard !hasLoaded else { return }
        cachedRecords = (try? fileStore.load()) ?? [:]
        hasLoaded = true
    }

    private func persist() {
        try? fileStore.save(cachedRecords)
    }

    private func cacheKey(for host: Host) -> String {
        "\(normalizedHost(host.address)):\(host.port)"
    }

    private func normalizedHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum SSHCompatibilityPlanner {
    static func nextProfile(
        afterFailureOutput output: String,
        currentProfile: SSHCompatibilityProfile,
        authMethod: AuthenticationMethod
    ) -> SSHCompatibilityProfile? {
        let lowercasedOutput = output.lowercased()

        if lowercasedOutput.contains("no matching key exchange method found") {
            let offered = offeredAlgorithms(from: output)
            if offered.contains(SSHCompatibilityKexAlgorithm.diffieHellmanGroup14SHA1.rawValue),
               currentProfile.kexAlgorithms.contains(.diffieHellmanGroup14SHA1) == false {
                return currentProfile.appendingKex(.diffieHellmanGroup14SHA1)
            }

            if offered.contains(SSHCompatibilityKexAlgorithm.diffieHellmanGroup1SHA1.rawValue),
               currentProfile.kexAlgorithms.contains(.diffieHellmanGroup1SHA1) == false {
                return currentProfile.appendingKex(.diffieHellmanGroup1SHA1)
            }
        }

        if lowercasedOutput.contains("no matching host key type found") {
            let offered = offeredAlgorithms(from: output)
            if offered.contains(SSHCompatibilityHostKeyAlgorithm.sshRSA.rawValue),
               currentProfile.hostKeyAlgorithms.contains(.sshRSA) == false {
                return currentProfile.appendingHostKey(.sshRSA)
            }

            if offered.contains(SSHCompatibilityHostKeyAlgorithm.sshDSS.rawValue),
               currentProfile.hostKeyAlgorithms.contains(.sshDSS) == false {
                return currentProfile.appendingHostKey(.sshDSS)
            }
        }

        if authMethod != .password,
           (lowercasedOutput.contains("pubkeyacceptedalgorithms")
            || (lowercasedOutput.contains("userauth_pubkey") && lowercasedOutput.contains("ssh-rsa"))
            || lowercasedOutput.contains("key type ssh-rsa not in pubkeyacceptedalgorithms")),
           currentProfile.pubkeyAcceptedAlgorithms.contains(.sshRSA) == false {
            return currentProfile.appendingPubkeyAccepted(.sshRSA)
        }

        return nil
    }

    private static func offeredAlgorithms(from output: String) -> [String] {
        let lines = output
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n")
            .map(String.init)

        guard let offerLine = lines.reversed().first(where: { $0.range(of: "their offer:", options: [.caseInsensitive]) != nil }),
              let range = offerLine.range(of: "their offer:", options: [.caseInsensitive]) else {
            return []
        }

        return offerLine[range.upperBound...]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}
