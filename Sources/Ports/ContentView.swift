import SwiftUI

/// Root popover content: Header / Body / Footer, fixed 300×500.
struct ContentView: View {
    @ObservedObject var viewModel: PortViewModel
    @State private var searchExpanded = false
    @State private var showCloseAllConfirm = false
    @State private var killError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 50)
                .padding(.horizontal, 12)
            Divider()
            portList
            Divider()
            footer
                .frame(height: 50)
                .padding(.horizontal, 12)
        }
        .frame(width: 300, height: 500)
        .confirmationDialog(
            "Close all ports?",
            isPresented: $showCloseAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Close all", role: .destructive) {
                viewModel.killAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will terminate \(viewModel.ports.count) process(es) with administrator privileges.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("Ports")
                .font(.headline)

            Spacer(minLength: 4)

            if searchExpanded {
                TextField("Search port name", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    searchExpanded.toggle()
                    if !searchExpanded { viewModel.searchText = "" }
                }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Search ports")

            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(viewModel.isProcessing ? 360 : 0))
                    .animation(
                        viewModel.isProcessing
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: viewModel.isProcessing
                    )
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    // MARK: Body

    private var portList: some View {
        let items = viewModel.filteredPorts
        return ScrollView {
            LazyVStack(spacing: 0) {
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(items) { port in
                        PortRow(port: port) {
                            viewModel.kill(port)
                        }
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "circle.dashed")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(viewModel.searchText.isEmpty ? "No ports found" : "No matching ports")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                if let url = URL(string: "http://google.com") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                    Text("Need Help?")
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("close all") {
                showCloseAllConfirm = true
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.ports.isEmpty)

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .font(.subheadline)
    }
}

/// A single port row.
private struct PortRow: View {
    let port: PortInfo
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(port.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("PID \(port.pid)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(port.execName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(port.projectDir.isEmpty ? "—" : port.projectDir)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.borderless)
            .help("Close process \(port.pid)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
