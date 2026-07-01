import Foundation
import Combine

/// Drives port data, search filtering and process termination for the UI.
/// MainActor-isolated: all UI state mutations happen on the main thread, so the
/// Task spawned in `runKill` inherits main-actor isolation and can touch `self`
/// without weak-capture / concurrency warnings.
@MainActor
final class PortViewModel: ObservableObject {
    /// All scanned ports (unfiltered).
    @Published private(set) var ports: [PortInfo] = []

    /// Current search text; filtering matches the port **name** field only.
    @Published var searchText: String = ""

    /// Whether a (possibly slow) refresh or kill is in flight.
    @Published private(set) var isProcessing: Bool = false

    /// Optional callback invoked whenever the port list changes (for badge updates).
    var onPortsChange: (() -> Void)?

    /// Ports after applying the current search filter.
    var filteredPorts: [PortInfo] {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return ports }
        return ports.filter { $0.name.localizedCaseInsensitiveContains(term) }
    }

    /// Refreshes the port list off the main thread.
    func refresh() {
        guard !isProcessing else { return }
        isProcessing = true
        Task {
            // Run the (synchronous, blocking) lsof scan off the main actor.
            let scanned = await Task.detached { PortScanner.scan() }.value
            self.ports = scanned
            self.isProcessing = false
            self.onPortsChange?()
        }
    }

    /// Kills a single port's process. No confirmation (per PRD).
    func kill(_ port: PortInfo) {
        runKill([port.pid])
    }

    /// Kills every currently-listed port's process.
    func killAll() {
        runKill(ports.map { $0.pid })
    }

    private func runKill(_ pids: [pid_t]) {
        guard !pids.isEmpty, !isProcessing else { return }
        isProcessing = true
        Task {
            _ = try? await ProcessKiller.kill(pids)
            // Give the kernel a moment to release the ports, then refresh.
            try? await Task.sleep(nanoseconds: 400_000_000)
            self.isProcessing = false
            self.refresh()
        }
    }
}
