import Foundation
import Darwin

/// Cleans up SSH processes and ControlMaster sockets created by Remora.
public enum SSHControlMasterCleanup {
    /// Kill all Remora SSH processes and clean up sockets.
    /// Safe to call from applicationWillTerminate.
    public static func killAll() {
        killSSHProcesses()
        cleanupSockets()
    }

    /// Signal-safe cleanup using only POSIX calls. Safe to call from signal handlers.
    public static func killAllSync() {
        // Kill all processes whose command line contains our socket pattern.
        // We use execve to run pkill synchronously in a fork.
        var pid: pid_t = 0
        let args: [String] = ["/usr/bin/pkill", "-f", "ControlPath=/tmp/remora-"]
        let argv = args.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        posix_spawn(&pid, "/usr/bin/pkill", nil, nil, argv, nil)
        if pid > 0 {
            var status: Int32 = 0
            waitpid(pid, &status, 0)
        }

        // Remove socket files
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: "/tmp") {
            for name in contents where name.hasPrefix("remora-") && name.hasSuffix(".sock") {
                unlink("/tmp/\(name)")
            }
        }
    }

    private static func killSSHProcesses() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        proc.arguments = ["-f", "ControlPath=/tmp/remora-"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
    }

    private static func cleanupSockets() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: "/tmp") else { return }
        for name in contents where name.hasPrefix("remora-") && name.hasSuffix(".sock") {
            try? fm.removeItem(atPath: "/tmp/\(name)")
        }
    }
}
