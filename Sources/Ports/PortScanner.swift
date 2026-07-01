import Foundation

/// A single occupied network port entry.
struct PortInfo: Identifiable, Hashable {
    /// Stable identity across refreshes.
    var id: String { "\(pid)-\(name)-\(execName)" }

    /// Port name / protocol identifier (e.g. `*:3000 (LISTEN)`).
    let name: String
    /// PID of the owning process.
    let pid: pid_t
    /// Command / executable that opened the port.
    let execName: String
    /// Working directory of the owning process, if resolvable.
    let projectDir: String
}

/// Scans the system for occupied network ports using `lsof`.
enum PortScanner {
    /// All TCP LISTEN, UDP and TCP ESTABLISHED entries.
    static func scan() -> [PortInfo] {
        let cwdMap = fetchCwdMap()
        return parseNetwork(output: run(lsof: ["-i", "-P", "-n"]), cwdMap: cwdMap)
    }

    // MARK: - Helpers

    private static func run(lsof args: [String]) -> String {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// pid -> working directory path, gathered in one `lsof -d cwd` pass.
    private static func fetchCwdMap() -> [pid_t: String] {
        let output = run(lsof: ["-d", "cwd", "-F", "pn"])
        var map: [pid_t: String] = [:]
        var currentPid: pid_t?
        for line in output.split(separator: "\n") {
            guard let first = line.first else { continue }
            let rest = String(line.dropFirst())
            switch first {
            case "p":
                currentPid = pid_t(rest)
            case "n":
                if let pid = currentPid, !rest.isEmpty {
                    map[pid] = rest
                }
            default:
                break
            }
        }
        return map
    }

    private static func parseNetwork(output: String, cwdMap: [pid_t: String]) -> [PortInfo] {
        var results: [PortInfo] = []
        for line in output.split(separator: "\n") {
            // Header lines.
            if line.hasPrefix("COMMAND") { continue }

            // NOTE: do NOT use maxSplits with omittingEmptySubsequences here —
            // consecutive spaces between columns consume split quota on empty
            // subsequences, which misaligns the NAME field. Instead, collapse to
            // non-empty tokens and locate NAME (which starts with TCP/UDP) by
            // content, since earlier columns (e.g. NODE) may be empty.
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
            guard tokens.count >= 2 else { continue }

            let command = String(tokens[0])
            guard let pid = pid_t(tokens[1]) else { continue }

            // The NAME field always begins with "TCP" or "UDP" for network entries.
            guard let nameStart = tokens.firstIndex(where: {
                $0.hasPrefix("TCP") || $0.hasPrefix("UDP")
            }) else { continue }
            let name = tokens[nameStart...].joined(separator: " ")

            // Only IPv4/IPv6 network entries (TYPE column).
            guard tokens.contains(where: { $0.hasPrefix("IPv") }) else { continue }
            // Skip UDP entries with no real port (e.g. "UDP *:*").
            if name.hasPrefix("UDP") && name.contains("*:*") { continue }

            results.append(
                PortInfo(
                    name: name,
                    pid: pid,
                    execName: command,
                    projectDir: cwdMap[pid] ?? ""
                )
            )
        }
        // Stable, readable ordering: by port name.
        return results.sorted { $0.name < $1.name }
    }
}
