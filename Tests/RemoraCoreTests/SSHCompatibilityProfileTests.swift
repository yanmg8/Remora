import Foundation
import Testing
@testable import RemoraCore

struct SSHCompatibilityProfileTests {
    @Test
    func plannerPrefersGroup14BeforeGroup1ForLegacyKEXFailures() {
        let profile = SSHCompatibilityProfile()
        let output = """
        Unable to negotiate with 10.0.0.2 port 22: no matching key exchange method found.
        Their offer: diffie-hellman-group14-sha1,diffie-hellman-group1-sha1
        """

        let next = SSHCompatibilityPlanner.nextProfile(
            afterFailureOutput: output,
            currentProfile: profile,
            authMethod: .agent
        )

        #expect(next?.kexAlgorithms == [.diffieHellmanGroup14SHA1])
        #expect(next?.hostKeyAlgorithms.isEmpty == true)
        #expect(next?.pubkeyAcceptedAlgorithms.isEmpty == true)
    }

    @Test
    func plannerEscalatesToGroup1AfterGroup14IsAlreadyEnabled() {
        let profile = SSHCompatibilityProfile(kexAlgorithms: [.diffieHellmanGroup14SHA1])
        let output = """
        Unable to negotiate with 10.0.0.2 port 22: no matching key exchange method found.
        Their offer: diffie-hellman-group14-sha1,diffie-hellman-group1-sha1
        """

        let next = SSHCompatibilityPlanner.nextProfile(
            afterFailureOutput: output,
            currentProfile: profile,
            authMethod: .agent
        )

        #expect(next?.kexAlgorithms == [.diffieHellmanGroup14SHA1, .diffieHellmanGroup1SHA1])
    }

    @Test
    func plannerEnablesSSHRSAHostKeyBeforeDSS() {
        let output = """
        Unable to negotiate with legacyhost: no matching host key type found. Their offer: ssh-rsa,ssh-dss
        """

        let next = SSHCompatibilityPlanner.nextProfile(
            afterFailureOutput: output,
            currentProfile: SSHCompatibilityProfile(),
            authMethod: .agent
        )

        #expect(next?.hostKeyAlgorithms == [.sshRSA])
    }

    @Test
    func plannerOnlyEnablesDSSHostKeyWhenServerOffersOnlyDSS() {
        let output = """
        Unable to negotiate with legacyhost: no matching host key type found. Their offer: ssh-dss
        """

        let next = SSHCompatibilityPlanner.nextProfile(
            afterFailureOutput: output,
            currentProfile: SSHCompatibilityProfile(),
            authMethod: .agent
        )

        #expect(next?.hostKeyAlgorithms == [.sshDSS])
    }

    @Test
    func plannerEnablesSSHRSAPubkeyFallbackForUserAuthFailures() {
        let output = "userauth_pubkey: key type ssh-rsa not in PubkeyAcceptedAlgorithms"

        let next = SSHCompatibilityPlanner.nextProfile(
            afterFailureOutput: output,
            currentProfile: SSHCompatibilityProfile(),
            authMethod: .privateKey
        )

        #expect(next?.pubkeyAcceptedAlgorithms == [.sshRSA])
    }

    @Test
    func plannerSkipsPubkeyFallbackForPasswordOnlyHosts() {
        let output = "userauth_pubkey: key type ssh-rsa not in PubkeyAcceptedAlgorithms"

        let next = SSHCompatibilityPlanner.nextProfile(
            afterFailureOutput: output,
            currentProfile: SSHCompatibilityProfile(),
            authMethod: .password
        )

        #expect(next == nil)
    }

    @Test
    func sshArgumentsAppendCompatibilityOptions() {
        let host = Host(
            name: "legacy",
            address: "10.0.0.2",
            username: "root",
            auth: HostAuth(method: .agent)
        )
        let profile = SSHCompatibilityProfile(
            kexAlgorithms: [.diffieHellmanGroup14SHA1, .diffieHellmanGroup1SHA1],
            hostKeyAlgorithms: [.sshRSA],
            pubkeyAcceptedAlgorithms: [.sshRSA]
        )

        let args = ProcessSSHShellSession.makeSSHArguments(for: host, compatibilityProfile: profile)

        #expect(args.contains("KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1"))
        #expect(args.contains("HostKeyAlgorithms=+ssh-rsa"))
        #expect(args.contains("PubkeyAcceptedAlgorithms=+ssh-rsa"))
        #expect(args.contains("StrictHostKeyChecking=ask"))
    }

    @Test
    func sftpArgumentsAppendCompatibilityOptions() {
        let host = Host(
            name: "legacy",
            address: "10.0.0.2",
            username: "root",
            auth: HostAuth(method: .agent)
        )
        let profile = SSHCompatibilityProfile(hostKeyAlgorithms: [.sshRSA])

        let args = SystemSFTPClient.makeSFTPArguments(for: host, compatibilityProfile: profile)

        #expect(args.contains("HostKeyAlgorithms=+ssh-rsa"))
        #expect(args.contains("BatchMode=yes"))
    }

    @Test
    func compatibilityStorePersistsProfilesPerHostPort() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remora-ssh-compat-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = SSHCompatibilityProfileStore(baseDirectoryURL: root)
        let host = Host(
            name: "legacy",
            address: "10.0.0.2",
            port: 2222,
            username: "root",
            auth: HostAuth(method: .agent)
        )
        let profile = SSHCompatibilityProfile(kexAlgorithms: [.diffieHellmanGroup14SHA1])

        await store.recordSuccess(profile: profile, for: host, fingerprint: "SHA256:abc")
        let loaded = await store.cachedProfile(for: host)
        let record = await store.cachedRecord(for: host)

        #expect(loaded == profile)
        #expect(record?.fingerprint == "SHA256:abc")
        #expect(record?.host == "10.0.0.2")
        #expect(record?.port == 2222)

        await store.recordSuccess(profile: SSHCompatibilityProfile(), for: host, fingerprint: nil)
        let cleared = await store.cachedProfile(for: host)
        #expect(cleared == nil)
    }
}
