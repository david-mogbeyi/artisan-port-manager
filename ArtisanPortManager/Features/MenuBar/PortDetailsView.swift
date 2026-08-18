import SwiftUI

struct PortDetailsView: View {
    let port: ListeningPort
    @ObservedObject var state: AppState
    @State private var pendingForce = false
    @State private var showsConfirmation = false
    private let browser = BrowserService()
    private let clipboard = ClipboardService()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "network")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(port.port))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                            Text(port.processName).font(.headline).textSelection(.enabled)
                        }
                        Spacer()
                        Label("Listening", systemImage: "circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    }

                    quickActions
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
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
            }

            Divider()
            destructiveActionBar
        }
        .navigationTitle("Port " + String(port.port))
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
        HStack(spacing: 8) {
            Button { browser.open(port: port) } label: { Label("Open", systemImage: "safari") }
            Button { clipboard.copy("http://localhost:\(port.port)") } label: { Label("Copy URL", systemImage: "link") }
            Menu {
                Button("Port") { clipboard.copy(String(port.port)) }
                Button("PID") { clipboard.copy(String(port.pid)) }
                Button("Process Name") { clipboard.copy(port.processName) }
                if let cwd = port.workingDirectory { Button("Working Directory") { clipboard.copy(cwd) } }
                Button("Full Process Information") { clipboard.copy(port.fullDescription) }
                if let cwd = port.workingDirectory {
                    Divider()
                    Button("Reveal Project in Finder") { browser.reveal(directory: cwd) }
                }
            } label: { Label("More", systemImage: "ellipsis.circle") }
            Spacer()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var destructiveActionBar: some View {
        HStack(spacing: 8) {
            Button("Terminate", role: .destructive) { confirm(force: false) }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            Button("Force Kill", role: .destructive) { confirm(force: true) }
                .buttonStyle(.bordered)
            Spacer()
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
