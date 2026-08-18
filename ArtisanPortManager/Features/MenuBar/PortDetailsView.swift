import SwiftUI

struct PortDetailsView: View {
    let port: ListeningPort
    @ObservedObject var state: AppState
    @State private var pendingForce = false
    @State private var showsConfirmation = false
    @State private var isRenaming = false
    private let browser = BrowserService()
    private let clipboard = ClipboardService()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "network")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(port.port))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(state.alias(for: port) ?? port.processName)
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            if state.alias(for: port) != nil {
                                Text(port.processName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 8)
                        Button { state.toggleFavorite(port) } label: {
                            Image(systemName: state.isFavorite(port) ? "star.fill" : "star")
                                .foregroundStyle(state.isFavorite(port) ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(state.isFavorite(port) ? "Remove from Favorites" : "Add to Favorites")
                        .accessibilityLabel(state.isFavorite(port) ? "Remove from Favorites" : "Add to Favorites")
                        Label(state.reachability(for: port).label, systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(statusColor)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    quickActions
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        reachabilityDetail
                        detail("Project", port.projectName)
                        detail("PID", String(port.pid))
                        detail("Address", port.endpoint)
                        detail("User", port.user)
                        detail("Working Directory", port.workingDirectory, lineLimit: 2)
                        detail("Executable", port.executablePath, lineLimit: 2)
                        detail("Command", port.command, lineLimit: 3)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            destructiveActionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Port " + String(port.port))
        .sheet(isPresented: $isRenaming) {
            RenamePortView(port: port, currentAlias: state.alias(for: port)) { alias in
                state.setAlias(alias, for: port)
            }
        }
        .confirmationDialog(pendingForce ? "Force kill \(port.processName)?" : "Terminate \(port.processName) on port \(port.port)?",
                            isPresented: $showsConfirmation, titleVisibility: .visible) {
            Button(pendingForce ? "Force Kill" : "Terminate", role: .destructive) {
                Task { await state.terminate(port, force: pendingForce) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if pendingForce { Text("The process will not be given a chance to shut down cleanly.") }
            else { Text("The process will receive SIGTERM and can shut down cleanly.") }
        }
    }

    private var statusColor: Color {
        switch state.reachability(for: port) {
        case .http: return .green
        case .tcpOnly: return .blue
        case .unreachable: return .orange
        case .probing: return .gray
        case .unknown: return .green
        }
    }

    /// Reachability gets its own row with a re-check control, since it is the one piece of
    /// detail here that can change without the process changing.
    private var reachabilityDetail: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("REACHABILITY")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(state.reachability(for: port).detailLabel)
                    .font(.callout)
                    .textSelection(.enabled)
                Spacer(minLength: 4)
                Button { Task { await state.probe(port) } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Check this port again")
                .accessibilityLabel("Check this port again")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func detail(_ label: String, _ value: String?, lineLimit: Int = 1) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .textSelection(.enabled)
                    .lineLimit(lineLimit)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var quickActions: some View {
        ViewThatFits(in: .horizontal) {
            quickActionButtons(spacing: 8)
            quickActionButtons(spacing: 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickActionButtons(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Button {
                browser.open(port: port, reachability: state.reachability(for: port))
            } label: { Label("Open", systemImage: "safari") }
            Button {
                clipboard.copy("\(state.reachability(for: port).preferredScheme)://localhost:\(port.port)")
            } label: { Label("Copy URL", systemImage: "link") }
            Menu {
                Button("Port") { clipboard.copy(String(port.port)) }
                Button("PID") { clipboard.copy(String(port.pid)) }
                Button("Process Name") { clipboard.copy(port.processName) }
                if let cwd = port.workingDirectory { Button("Working Directory") { clipboard.copy(cwd) } }
                Button("Full Process Information") { clipboard.copy(port.fullDescription) }
                Divider()
                Button(state.alias(for: port) == nil ? "Rename…" : "Edit Alias…") { isRenaming = true }
                if let cwd = port.workingDirectory {
                    Divider()
                    Button("Reveal Project in Finder") { browser.reveal(directory: cwd) }
                }
            } label: { Label("More", systemImage: "ellipsis.circle") }
            .fixedSize()
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }

    private var destructiveActionBar: some View {
        HStack(spacing: 8) {
            Button("Terminate", role: .destructive) { confirm(force: false) }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            Button("Force Kill", role: .destructive) { confirm(force: true) }
                .buttonStyle(.bordered)
            Spacer(minLength: 0)
            if state.terminatingPIDs.contains(port.pid) { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .disabled(state.terminatingPIDs.contains(port.pid))
    }

    private func confirm(force: Bool) {
        pendingForce = force
        showsConfirmation = true
    }
}
