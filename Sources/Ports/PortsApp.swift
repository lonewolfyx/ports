import AppKit
import SwiftUI

@main
enum PortsApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Hide Dock icon (equivalent to LSUIElement = YES).
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let viewModel = PortViewModel()
    private var refreshTimer: Timer?

    // First-version badge is a static placeholder per PRD §2.1/§6.1.
    private let badgeText = "8"

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(viewModel: viewModel)
        )

        // Initial load + 30s auto refresh (PRD §4 / AC).
        viewModel.refresh()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            // Timer fires on the main run loop; hop into main-actor context.
            Task { @MainActor in self?.viewModel.refresh() }
        }

        viewModel.onPortsChange = {
            // Hook for future dynamic badge; first version stays static "8".
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = loadMenuBarIcon()
        button.imagePosition = .imageLeft
        button.title = badgeText
        button.target = self
        button.action = #selector(togglePopover)
    }

    private func loadMenuBarIcon() -> NSImage? {
        if let url = Bundle.module.url(forResource: "app-light", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            // Render as a template so it adapts to light/dark menu bar.
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        return NSImage(systemSymbolName: "network", accessibilityDescription: "Ports")
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
