import Foundation
import RemoraCore

struct SSHHostMetricsKey: Hashable, Sendable {
    let address: String
    let port: Int
    let username: String

    init(host: RemoraCore.Host) {
        self.address = host.address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.port = host.port
        self.username = host.username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var title: String {
        "\(username)@\(address):\(port)"
    }
}

struct ServerResourceMetricsSnapshot: Equatable, Sendable {
    let cpuFraction: Double?
    let memoryFraction: Double?
    let swapFraction: Double?
    let diskFraction: Double?
    let memoryUsedBytes: Int64?
    let memoryTotalBytes: Int64?
    let swapUsedBytes: Int64?
    let swapTotalBytes: Int64?
    let diskUsedBytes: Int64?
    let diskTotalBytes: Int64?
    let processCount: Int64?
    let networkRXBytes: Int64?
    let networkTXBytes: Int64?
    let diskReadBytes: Int64?
    let diskWriteBytes: Int64?
    let loadAverage1: Double?
    let loadAverage5: Double?
    let loadAverage15: Double?
    let uptimeSeconds: Int64?
    let topProcesses: [ServerTopProcessMetric]
    let filesystems: [ServerFilesystemMetric]
    let sampledAt: Date
}

struct ServerTopProcessMetric: Equatable, Sendable {
    let memoryBytes: Int64?
    let cpuPercent: Double?
    let command: String
}

struct ServerFilesystemMetric: Equatable, Sendable {
    let mountPath: String
    let availableBytes: Int64?
    let totalBytes: Int64?
}

struct ServerHostMetricsState: Equatable, Sendable {
    var snapshot: ServerResourceMetricsSnapshot?
    var previousSnapshot: ServerResourceMetricsSnapshot?
    var isLoading: Bool
    var errorMessage: String?
    var lastAttemptAt: Date?

    static let idle = ServerHostMetricsState(
        snapshot: nil,
        previousSnapshot: nil,
        isLoading: false,
        errorMessage: nil,
        lastAttemptAt: nil
    )
}

actor RemoteServerMetricsProbe {
    private static let metricsCommand = """
    LC_ALL=C /bin/sh <<'REMORA_METRICS'
    cpu_permille=-1
    if [ -r /proc/stat ]; then
      read -r _ u n s i io irq sirq st _ < /proc/stat
      t1=$((u+n+s+i+io+irq+sirq+st))
      idle1=$((i+io))
      sleep 0.2
      read -r _ u2 n2 s2 i2 io2 irq2 sirq2 st2 _ < /proc/stat
      t2=$((u2+n2+s2+i2+io2+irq2+sirq2+st2))
      idle2=$((i2+io2))
      dt=$((t2-t1))
      didle=$((idle2-idle1))
      if [ "$dt" -gt 0 ]; then
        cpu_permille=$((1000*(dt-didle)/dt))
      fi
    fi

    mem_total_kb=-1
    mem_used_kb=-1
    swap_total_kb=-1
    swap_used_kb=-1
    if [ -r /proc/meminfo ]; then
      mem_total_kb=$(awk '/MemTotal:/ {print $2; exit}' /proc/meminfo)
      mem_available_kb=$(awk '/MemAvailable:/ {print $2; exit}' /proc/meminfo)
      swap_total_kb=$(awk '/SwapTotal:/ {print $2; exit}' /proc/meminfo)
      swap_free_kb=$(awk '/SwapFree:/ {print $2; exit}' /proc/meminfo)
      if [ -n "$mem_total_kb" ] && [ -n "$mem_available_kb" ]; then
        mem_used_kb=$((mem_total_kb-mem_available_kb))
      fi
      if [ -n "$swap_total_kb" ] && [ -n "$swap_free_kb" ]; then
        swap_used_kb=$((swap_total_kb-swap_free_kb))
      fi
    fi

    disk_total_kb=-1
    disk_used_kb=-1
    set -- $(df -Pk / 2>/dev/null | awk 'NR==2 {print $2, $3}')
    if [ "$#" -ge 2 ]; then
      disk_total_kb=$1
      disk_used_kb=$2
    fi

    load1=-1
    load5=-1
    load15=-1
    if [ -r /proc/loadavg ]; then
      set -- $(awk '{print $1, $2, $3; exit}' /proc/loadavg)
      if [ "$#" -ge 3 ]; then
        load1=$1
        load5=$2
        load15=$3
      fi
    fi

    uptime_s=-1
    if [ -r /proc/uptime ]; then
      uptime_s=$(awk '{print int($1); exit}' /proc/uptime)
    fi

    proc_count=-1
    if [ -d /proc ]; then
      proc_count=$(ls -1 /proc 2>/dev/null | awk '/^[0-9]+$/ {count++} END {print count+0}')
    fi

    net_rx_bytes=-1
    net_tx_bytes=-1
    if [ -r /proc/net/dev ]; then
      set -- $(awk -F':' 'NR>2 {
        iface=$1
        gsub(/ /, "", iface)
        if (iface == "lo" || iface == "") next
        gsub(/^ +/, "", $2)
        split($2, a, / +/)
        rx+=a[1]
        tx+=a[9]
      } END {print rx+0, tx+0}' /proc/net/dev)
      if [ "$#" -ge 2 ]; then
        net_rx_bytes=$1
        net_tx_bytes=$2
      fi
    fi

    disk_read_bytes=-1
    disk_write_bytes=-1
    disk_read_sectors=0
    disk_write_sectors=0
    disk_io_found=0
    if [ -d /sys/block ]; then
      for stat in /sys/block/*/stat; do
        [ -r "$stat" ] || continue
        dev=$(basename "$(dirname "$stat")")
        case "$dev" in
          loop*|ram*|fd*|sr*) continue ;;
        esac
        read -r _ _ rs _ _ _ _ _ ws _ _ _ _ _ _ _ < "$stat"
        if [ -n "$rs" ] && [ -n "$ws" ]; then
          disk_read_sectors=$((disk_read_sectors + rs))
          disk_write_sectors=$((disk_write_sectors + ws))
          disk_io_found=1
        fi
      done
    fi
    if [ "$disk_io_found" -eq 1 ]; then
      disk_read_bytes=$((disk_read_sectors * 512))
      disk_write_bytes=$((disk_write_sectors * 512))
    fi

    ps -eo rss=,pcpu=,comm= --sort=-rss 2>/dev/null \
      | awk 'NR<=4 {
          rss=$1
          cpu=$2
          cmd=$3
          if (cmd == "") next
          printf("proc_%d=%s|%s|%s\\n", NR-1, rss, cpu, cmd)
        }'

    df -Pk 2>/dev/null \
      | awk 'NR>1 && count<4 {
          mount=""
          for (i=6; i<=NF; i++) {
            mount = mount (i == 6 ? "" : " ") $i
          }
          if (mount == "") next
          printf("fs_%d=%s|%s|%s\\n", count, mount, $4, $2)
          count++
        }'

    printf 'cpu_permille=%s\\n' "$cpu_permille"
    printf 'mem_total_kb=%s\\n' "$mem_total_kb"
    printf 'mem_used_kb=%s\\n' "$mem_used_kb"
    printf 'swap_total_kb=%s\\n' "$swap_total_kb"
    printf 'swap_used_kb=%s\\n' "$swap_used_kb"
    printf 'disk_total_kb=%s\\n' "$disk_total_kb"
    printf 'disk_used_kb=%s\\n' "$disk_used_kb"
    printf 'load1=%s\\n' "$load1"
    printf 'load5=%s\\n' "$load5"
    printf 'load15=%s\\n' "$load15"
    printf 'uptime_s=%s\\n' "$uptime_s"
    printf 'proc_count=%s\\n' "$proc_count"
    printf 'net_rx_bytes=%s\\n' "$net_rx_bytes"
    printf 'net_tx_bytes=%s\\n' "$net_tx_bytes"
    printf 'disk_read_bytes=%s\\n' "$disk_read_bytes"
    printf 'disk_write_bytes=%s\\n' "$disk_write_bytes"
    REMORA_METRICS
    """

    private var clients: [SSHHostMetricsKey: SystemSFTPClient] = [:]

    func sample(host: RemoraCore.Host) async throws -> ServerResourceMetricsSnapshot {
        let key = SSHHostMetricsKey(host: host)
        let client = clientForHost(host, key: key)
        let output = try await client.executeRemoteShellCommand(Self.metricsCommand, timeout: 5.5)
        guard let snapshot = Self.parseSnapshot(from: output) else {
            throw SSHError.connectionFailed("metrics output parsing failed")
        }
        return snapshot
    }

    private func clientForHost(_ host: RemoraCore.Host, key: SSHHostMetricsKey) -> SystemSFTPClient {
        if let existing = clients[key] {
            return existing
        }
        let client = SystemSFTPClient(host: host)
        clients[key] = client
        return client
    }

    static func parseSnapshot(
        from output: String,
        sampledAt: Date = Date()
    ) -> ServerResourceMetricsSnapshot? {
        var values: [String: String] = [:]
        let lines = output
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            values[key] = value
        }

        func parseNonNegativeInt(_ key: String) -> Int64? {
            guard let raw = values[key], let value = Int64(raw), value >= 0 else {
                return nil
            }
            return value
        }

        func parseNonNegativeDouble(_ key: String) -> Double? {
            guard let raw = values[key], let value = Double(raw), value >= 0 else {
                return nil
            }
            return value
        }

        let cpuPermille = parseNonNegativeInt("cpu_permille")
        let memoryTotalKB = parseNonNegativeInt("mem_total_kb")
        let memoryUsedKB = parseNonNegativeInt("mem_used_kb")
        let swapTotalKB = parseNonNegativeInt("swap_total_kb")
        let swapUsedKB = parseNonNegativeInt("swap_used_kb")
        let diskTotalKB = parseNonNegativeInt("disk_total_kb")
        let diskUsedKB = parseNonNegativeInt("disk_used_kb")
        let loadAverage1 = parseNonNegativeDouble("load1")
        let loadAverage5 = parseNonNegativeDouble("load5")
        let loadAverage15 = parseNonNegativeDouble("load15")
        let uptimeSeconds = parseNonNegativeInt("uptime_s")
        let processCount = parseNonNegativeInt("proc_count")
        let networkRXBytes = parseNonNegativeInt("net_rx_bytes")
        let networkTXBytes = parseNonNegativeInt("net_tx_bytes")
        let diskReadBytes = parseNonNegativeInt("disk_read_bytes")
        let diskWriteBytes = parseNonNegativeInt("disk_write_bytes")
        let topProcesses = (0..<4).compactMap { parseTopProcess(values["proc_\($0)"]) }
        let filesystems = (0..<4).compactMap { parseFilesystem(values["fs_\($0)"]) }

        let cpuFraction = cpuPermille.map { clampFraction(Double($0) / 1000) }
        let memoryFraction = fraction(used: memoryUsedKB, total: memoryTotalKB)
        let swapFraction = fraction(used: swapUsedKB, total: swapTotalKB)
        let diskFraction = fraction(used: diskUsedKB, total: diskTotalKB)
        let memoryUsedBytes = memoryUsedKB.map { $0 * 1024 }
        let memoryTotalBytes = memoryTotalKB.map { $0 * 1024 }
        let swapUsedBytes = swapUsedKB.map { $0 * 1024 }
        let swapTotalBytes = swapTotalKB.map { $0 * 1024 }
        let diskUsedBytes = diskUsedKB.map { $0 * 1024 }
        let diskTotalBytes = diskTotalKB.map { $0 * 1024 }

        if cpuFraction == nil,
           memoryFraction == nil,
           swapFraction == nil,
           diskFraction == nil,
           loadAverage1 == nil,
           loadAverage5 == nil,
           loadAverage15 == nil,
           uptimeSeconds == nil,
           processCount == nil,
           networkRXBytes == nil,
           networkTXBytes == nil,
           diskReadBytes == nil,
           diskWriteBytes == nil,
           topProcesses.isEmpty,
           filesystems.isEmpty
        {
            return nil
        }

        return ServerResourceMetricsSnapshot(
            cpuFraction: cpuFraction,
            memoryFraction: memoryFraction,
            swapFraction: swapFraction,
            diskFraction: diskFraction,
            memoryUsedBytes: memoryUsedBytes,
            memoryTotalBytes: memoryTotalBytes,
            swapUsedBytes: swapUsedBytes,
            swapTotalBytes: swapTotalBytes,
            diskUsedBytes: diskUsedBytes,
            diskTotalBytes: diskTotalBytes,
            processCount: processCount,
            networkRXBytes: networkRXBytes,
            networkTXBytes: networkTXBytes,
            diskReadBytes: diskReadBytes,
            diskWriteBytes: diskWriteBytes,
            loadAverage1: loadAverage1,
            loadAverage5: loadAverage5,
            loadAverage15: loadAverage15,
            uptimeSeconds: uptimeSeconds,
            topProcesses: topProcesses,
            filesystems: filesystems,
            sampledAt: sampledAt
        )
    }

    private static func parseTopProcess(_ raw: String?) -> ServerTopProcessMetric? {
        guard let raw else { return nil }
        let parts = raw.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let command = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return nil }
        let memoryBytes = Int64(parts[0]).map { max(0, $0) * 1024 }
        let cpuPercent = Double(parts[1]).map { max(0, $0) }
        return ServerTopProcessMetric(memoryBytes: memoryBytes, cpuPercent: cpuPercent, command: command)
    }

    private static func parseFilesystem(_ raw: String?) -> ServerFilesystemMetric? {
        guard let raw else { return nil }
        let parts = raw.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let mountPath = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mountPath.isEmpty else { return nil }
        let availableBytes = Int64(parts[1]).map { max(0, $0) * 1024 }
        let totalBytes = Int64(parts[2]).map { max(0, $0) * 1024 }
        return ServerFilesystemMetric(mountPath: mountPath, availableBytes: availableBytes, totalBytes: totalBytes)
    }

    private static func fraction(used: Int64?, total: Int64?) -> Double? {
        guard let used, let total, total > 0 else { return nil }
        return clampFraction(Double(used) / Double(total))
    }

    private static func clampFraction(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

@MainActor
final class ServerMetricsCenter: ObservableObject {
    @Published private(set) var states: [SSHHostMetricsKey: ServerHostMetricsState] = [:]

    private let probe = RemoteServerMetricsProbe()
    private var activeRefreshInterval: TimeInterval
    private var inactiveRefreshInterval: TimeInterval
    private let retentionInterval: TimeInterval
    private var maxConcurrentFetches: Int

    private var trackedHosts: [SSHHostMetricsKey: RemoraCore.Host] = [:]
    private var activeHostKey: SSHHostMetricsKey?
    private var inFlightKeys: Set<SSHHostMetricsKey> = []
    private var lastFetchAt: [SSHHostMetricsKey: Date] = [:]
    private var lastSeenAt: [SSHHostMetricsKey: Date] = [:]
    private var pollingTask: Task<Void, Never>?

    init(
        activeRefreshInterval: TimeInterval = TimeInterval(AppSettings.defaultServerMetricsActiveRefreshSeconds),
        inactiveRefreshInterval: TimeInterval = TimeInterval(AppSettings.defaultServerMetricsInactiveRefreshSeconds),
        retentionInterval: TimeInterval = 45,
        maxConcurrentFetches: Int = AppSettings.defaultServerMetricsMaxConcurrentFetches
    ) {
        let normalizedActive = TimeInterval(AppSettings.clampedServerMetricsActiveRefreshSeconds(Int(activeRefreshInterval.rounded())))
        let normalizedInactiveCandidate = TimeInterval(AppSettings.clampedServerMetricsInactiveRefreshSeconds(Int(inactiveRefreshInterval.rounded())))
        let normalizedInactive = max(normalizedInactiveCandidate, normalizedActive)
        self.activeRefreshInterval = normalizedActive
        self.inactiveRefreshInterval = normalizedInactive
        self.retentionInterval = retentionInterval
        self.maxConcurrentFetches = AppSettings.clampedServerMetricsMaxConcurrentFetches(maxConcurrentFetches)
        startPollingLoop()
    }

    deinit {
        pollingTask?.cancel()
    }

    func updateTrackedHosts(_ hosts: [RemoraCore.Host], activeHost: RemoraCore.Host?) {
        let now = Date()
        var unique: [SSHHostMetricsKey: RemoraCore.Host] = [:]
        unique.reserveCapacity(hosts.count)
        for host in hosts {
            let key = SSHHostMetricsKey(host: host)
            unique[key] = host
            lastSeenAt[key] = now
        }
        trackedHosts = unique
        activeHostKey = activeHost.map(SSHHostMetricsKey.init(host:))
        cleanupStaleEntries(now: now)
    }

    func state(for host: RemoraCore.Host?) -> ServerHostMetricsState? {
        guard let host else { return nil }
        return states[SSHHostMetricsKey(host: host)]
    }

    func configure(
        activeRefreshInterval: TimeInterval,
        inactiveRefreshInterval: TimeInterval,
        maxConcurrentFetches: Int
    ) {
        let normalizedActive = TimeInterval(
            AppSettings.clampedServerMetricsActiveRefreshSeconds(Int(activeRefreshInterval.rounded()))
        )
        let normalizedInactiveCandidate = TimeInterval(
            AppSettings.clampedServerMetricsInactiveRefreshSeconds(Int(inactiveRefreshInterval.rounded()))
        )
        let normalizedInactive = max(normalizedInactiveCandidate, normalizedActive)
        let normalizedConcurrent = AppSettings.clampedServerMetricsMaxConcurrentFetches(maxConcurrentFetches)

        self.activeRefreshInterval = normalizedActive
        self.inactiveRefreshInterval = normalizedInactive
        self.maxConcurrentFetches = normalizedConcurrent
        scheduleDueFetches()
    }

    private func startPollingLoop() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.pollingLoop()
        }
    }

    private func pollingLoop() async {
        while !Task.isCancelled {
            scheduleDueFetches()
            try? await Task.sleep(for: .milliseconds(350))
        }
    }

    private func scheduleDueFetches() {
        let now = Date()
        let availableSlots = max(0, maxConcurrentFetches - inFlightKeys.count)
        guard availableSlots > 0 else { return }

        let dueHosts = trackedHosts.compactMap { key, host -> (key: SSHHostMetricsKey, host: RemoraCore.Host, age: TimeInterval, isActive: Bool)? in
            guard !inFlightKeys.contains(key) else { return nil }
            let interval = refreshInterval(for: key)
            let lastFetched = lastFetchAt[key] ?? .distantPast
            let age = now.timeIntervalSince(lastFetched)
            guard age >= interval else { return nil }
            return (key: key, host: host, age: age, isActive: key == activeHostKey)
        }
        .sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            return lhs.age > rhs.age
        }

        for due in dueHosts.prefix(availableSlots) {
            launchFetch(for: due.key, host: due.host, startedAt: now)
        }
    }

    private func refreshInterval(for key: SSHHostMetricsKey) -> TimeInterval {
        key == activeHostKey ? activeRefreshInterval : inactiveRefreshInterval
    }

    private func launchFetch(for key: SSHHostMetricsKey, host: RemoraCore.Host, startedAt: Date) {
        inFlightKeys.insert(key)

        var currentState = states[key] ?? .idle
        currentState.isLoading = true
        currentState.errorMessage = nil
        currentState.lastAttemptAt = startedAt
        states[key] = currentState

        Task(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.probe.sample(host: host)
                self.completeFetch(for: key, snapshot: snapshot, errorMessage: nil)
            } catch {
                self.completeFetch(
                    for: key,
                    snapshot: nil,
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    private func completeFetch(
        for key: SSHHostMetricsKey,
        snapshot: ServerResourceMetricsSnapshot?,
        errorMessage: String?
    ) {
        inFlightKeys.remove(key)
        lastFetchAt[key] = Date()

        var nextState = states[key] ?? .idle
        nextState.isLoading = false
        if let snapshot {
            nextState.previousSnapshot = nextState.snapshot
            nextState.snapshot = snapshot
            nextState.errorMessage = nil
        } else if let errorMessage {
            nextState.errorMessage = errorMessage
        }
        states[key] = nextState
    }

    private func cleanupStaleEntries(now: Date) {
        let trackedKeys = Set(trackedHosts.keys)
        let staleKeys = lastSeenAt.compactMap { key, lastSeen -> SSHHostMetricsKey? in
            guard !trackedKeys.contains(key) else { return nil }
            guard !inFlightKeys.contains(key) else { return nil }
            guard now.timeIntervalSince(lastSeen) > retentionInterval else { return nil }
            return key
        }

        guard !staleKeys.isEmpty else { return }
        for key in staleKeys {
            lastSeenAt.removeValue(forKey: key)
            lastFetchAt.removeValue(forKey: key)
            states.removeValue(forKey: key)
        }
    }
}
