import AppKit
import SwiftUI

struct PortListView: View {
    @ObservedObject var state: AppState
    @State private var pendingPort: ListeningPort?
    @State private var pendingForce = false
    @State private var showsConfirmation = false
    @State private var expandedPIDs: Set<pid_t> = []
    @State private var renamingPort: ListeningPort?
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
                List {
                    ForEach(state.filteredPortGroups) { group in
                        if group.isMultiPort {
                            groupHeader(group)
                            if expandedPIDs.contains(group.pid) {
                                ForEach(group.ports) { port in
                                    portRow(port, isNested: true)
                                }
                            }
                        } else {
                            portRow(group.representative, isNested: false)
                        }
                    }
                }
                .listStyle(.inset)
                .animation(.easeInOut(duration: 0.18), value: expandedPIDs)
            }
        }
        .navigationDestination(for: ListeningPort.self) { PortDetailsView(port: $0, state: state) }
        .sheet(item: $renamingPort) { port in
            RenamePortView(port: port, currentAlias: state.alias(for: port)) { alias in
                state.setAlias(alias, for: port)
            }
        }
        .confirmationDialog(confirmationTitle, isPresented: $showsConfirmation, titleVisibility: .visible) {
            Button(pendingForce ? "Force Kill" : "Terminate", role: .destructive) {
                if let pendingPort { Task { await state.terminate(pendingPort, force: pendingForce) } }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(confirmationMessage)
        }
    }

    /// Collapsed header for a multi-port process. Tapping toggles its ports rather than
    /// navigating, because the group itself is not a single terminable listener.
    @ViewBuilder private func groupHeader(_ group: PortGroup) -> some View {
        HStack(spacing: 8) {
            Button {
                if expandedPIDs.contains(group.pid) { expandedPIDs.remove(group.pid) }
                else { expandedPIDs.insert(group.pid) }
            } label: {
                PortGroupRowView(group: group,
                                 isExpanded: expandedPIDs.contains(group.pid),
                                 terminatingPIDs: state.terminatingPIDs,
                                 alias: state.alias(for: group.representative),
                                 isFavorite: group.ports.contains(where: state.isFavorite))
            }
            .buttonStyle(.plain)

            terminateButton(for: group.representative,
                            help: "Terminate \(group.processName) (PID \(group.pid)) and all \(group.ports.count) of its ports")
        }
        .contextMenu { groupContextMenu(for: group) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.processName), \(group.ports.count) ports, PID \(group.pid)")
        .accessibilityHint(expandedPIDs.contains(group.pid) ? "Collapse ports" : "Expand ports")
    }

    @ViewBuilder private func portRow(_ port: ListeningPort, isNested: Bool) -> some View {
        HStack(spacing: 8) {
            NavigationLink(value: port) {
                PortRowView(port: port,
                            isTerminating: state.terminatingPIDs.contains(port.pid),
                            alias: state.alias(for: port),
                            isFavorite: state.isFavorite(port),
                            reachability: state.reachability(for: port))
            }
            .buttonStyle(.plain)

            terminateButton(for: port,
                            help: "Terminate \(port.processName) on port \(port.port)")
        }
        .padding(.leading, isNested ? 18 : 0)
        .contextMenu { contextMenu(for: port) }
    }

    @ViewBuilder private func terminateButton(for port: ListeningPort, help: String) -> some View {
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
        .help(help)
        .accessibilityLabel(help)
    }

    @ViewBuilder private func groupContextMenu(for group: PortGroup) -> some View {
        Button(expandedPIDs.contains(group.pid) ? "Collapse Ports" : "Expand Ports") {
            if expandedPIDs.contains(group.pid) { expandedPIDs.remove(group.pid) }
            else { expandedPIDs.insert(group.pid) }
        }
        Button(state.isFavorite(group.representative) ? "Remove from Favorites" : "Add to Favorites") {
            state.toggleFavorite(group.representative)
        }
        Button(state.alias(for: group.representative) == nil ? "Rename…" : "Edit Alias…") {
            renamingPort = group.representative
        }
        Divider()
        Button("Copy All Ports") {
            clipboard.copy(group.ports.map { String($0.port) }.joined(separator: ", "))
        }
        Button("Copy PID") { clipboard.copy(String(group.pid)) }
        if let cwd = group.representative.workingDirectory {
            Button("Reveal Project in Finder") { browser.reveal(directory: cwd) }
        }
        Divider()
        Button("Terminate Process", role: .destructive) { confirm(group.representative, force: false) }
        Button("Force Kill Process", role: .destructive) { confirm(group.representative, force: true) }
    }

    @ViewBuilder private func contextMenu(for port: ListeningPort) -> some View {
        Button(state.isFavorite(port) ? "Remove from Favorites" : "Add to Favorites") {
            state.toggleFavorite(port)
        }
        Button(state.alias(for: port) == nil ? "Rename…" : "Edit Alias…") { renamingPort = port }
        Divider()
        Button("Open \(state.reachability(for: port).preferredScheme)://localhost:\(port.port)") {
            browser.open(port: port, reachability: state.reachability(for: port))
        }
        Button("Copy URL") {
            clipboard.copy("\(state.reachability(for: port).preferredScheme)://localhost:\(port.port)")
        }
        Button("Check Reachability") { Task { await state.probe(port) } }
        Button("Copy Port") { clipboard.copy(String(port.port)) }
        Button("Copy PID") { clipboard.copy(String(port.pid)) }
        if let cwd = port.workingDirectory { Button("Reveal Project in Finder") { browser.reveal(directory: cwd) } }
        Divider()
        Button("Terminate", role: .destructive) { confirm(port, force: false) }
        Button("Force Kill", role: .destructive) { confirm(port, force: true) }
    }

    /// Number of ports the pending process would take down. Terminating signals the whole
    /// PID, so a multi-port process loses every listener, not just the row that was clicked.
    private var pendingPortCount: Int {
        guard let pendingPort else { return 0 }
        return state.filteredPortGroups.first { $0.pid == pendingPort.pid }?.ports.count ?? 1
    }

    private var confirmationTitle: String {
        let name = pendingPort?.processName ?? "process"
        let action = pendingForce ? "Force kill" : "Terminate"
        guard let pendingPort else { return "\(action) \(name)?" }
        return pendingPortCount > 1
            ? "\(action) \(name) and its \(pendingPortCount) ports?"
            : "\(action) \(name) on port \(pendingPort.port)?"
    }

    private var confirmationMessage: String {
        var text = pendingForce
            ? "The process will not be given a chance to shut down cleanly."
            : "The process will receive SIGTERM and can shut down cleanly."
        if pendingPortCount > 1, let pendingPort,
           let group = state.filteredPortGroups.first(where: { $0.pid == pendingPort.pid }) {
            text += " This releases ports \(group.ports.map { String($0.port) }.joined(separator: ", "))."
        }
        return text
    }

    private func confirm(_ port: ListeningPort, force: Bool) {
        pendingPort = port
        pendingForce = force
        showsConfirmation = true
    }
}
