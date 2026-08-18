import AppKit
import SwiftUI

struct PortListView: View {
    @ObservedObject var state: AppState
    @State private var pendingPort: ListeningPort?
    @State private var pendingForce = false
    @State private var showsConfirmation = false
    private let browser = BrowserService()
    private let clipboard = ClipboardService()

    var body: some View {
        Group {
            if state.isRefreshing && state.ports.isEmpty {
                VStack(spacing: 10) { ProgressView(); Text("Scanning ports…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.filteredPorts.isEmpty {
                ContentUnavailableView(
                    state.searchText.isEmpty ? "No Listening Ports" : "No Matches",
                    systemImage: state.searchText.isEmpty ? "network.slash" : "magnifyingglass",
                    description: Text(state.searchText.isEmpty ? "No relevant TCP listeners were found." : "Try a different port, process, project, or PID."))
            } else {
                List(state.filteredPorts) { port in
                    HStack(spacing: 8) {
                        NavigationLink(value: port) {
                            PortRowView(port: port, isTerminating: state.terminatingPIDs.contains(port.pid))
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) { confirm(port, force: false) } label: {
                            if state.terminatingPIDs.contains(port.pid) {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "stop.circle")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                            }
                        }
                        .buttonStyle(.borderless)
                        .frame(width: 28, height: 28)
                        .disabled(state.terminatingPIDs.contains(port.pid))
                        .help("Terminate \(port.processName) on port \(port.port)")
                        .accessibilityLabel("Terminate \(port.processName) on port \(port.port)")
                    }
                    .contextMenu { contextMenu(for: port) }
                }
                .listStyle(.inset)
            }
        }
        .navigationDestination(for: ListeningPort.self) { PortDetailsView(port: $0, state: state) }
        .confirmationDialog(pendingForce ? "Force kill \(pendingPort?.processName ?? "process")?" : "Terminate \(pendingPort?.processName ?? "process") on port \(pendingPort.map { String($0.port) } ?? "")?",
                            isPresented: $showsConfirmation, titleVisibility: .visible) {
            Button(pendingForce ? "Force Kill" : "Terminate", role: .destructive) {
                if let pendingPort { Task { await state.terminate(pendingPort, force: pendingForce) } }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(pendingForce ? "The process will not be given a chance to shut down cleanly." : "The process will receive SIGTERM.")
        }
    }

    @ViewBuilder private func contextMenu(for port: ListeningPort) -> some View {
        Button("Open localhost:\(port.port)") { browser.open(port: port) }
        Button("Copy URL") { clipboard.copy("http://localhost:\(port.port)") }
        Button("Copy Port") { clipboard.copy(String(port.port)) }
        Button("Copy PID") { clipboard.copy(String(port.pid)) }
        if let cwd = port.workingDirectory { Button("Reveal Project in Finder") { browser.reveal(directory: cwd) } }
        Divider()
        Button("Terminate", role: .destructive) { confirm(port, force: false) }
        Button("Force Kill", role: .destructive) { confirm(port, force: true) }
    }

    private func confirm(_ port: ListeningPort, force: Bool) {
        pendingPort = port
        pendingForce = force
        showsConfirmation = true
    }
}
