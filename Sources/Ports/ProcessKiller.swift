import Foundation

/// Terminates processes using administrator privileges (the macOS GUI equivalent
/// of `sudo kill`), surfacing a system password prompt via `osascript`.
enum ProcessKiller {
    enum KillError: LocalizedError {
        case osascriptFailed(exitCode: Int32)

        var errorDescription: String? {
            switch self {
            case .osascriptFailed(let code):
                return "Failed to terminate process (osascript exit \(code))."
            }
        }
    }

    /// Kills the given PIDs with `kill`, escalated through administrator privileges.
    /// Runs off the main thread; callers should `await` the result.
    static func kill(_ pids: [pid_t]) async throws {
        guard !pids.isEmpty else { return }
        let pidsArg = pids.map(String.init).joined(separator: " ")
        let shell = "kill \(pidsArg)"

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "do shell script \"\(shell)\" with administrator privileges"]
        // Silence osascript's stdout/stderr; the system shows its own password dialog.
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw KillError.osascriptFailed(exitCode: task.terminationStatus)
        }
    }
}
