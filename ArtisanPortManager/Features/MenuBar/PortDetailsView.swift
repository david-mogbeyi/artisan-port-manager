import SwiftUI

struct PortDetailsView: View {
    let port: ListeningPort
    @ObservedObject var state: AppState
    @State private var pendingForce = false
    @State private var showsConfirmation = false
    private let browser = BrowserService()
    private let clipboard = ClipboardService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(port.port)).font(.system(size: 32, weight: .semibold, design: .rounded))
                    Spacer()
                    Label("Listening", systemImage: "circle.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                Text(port.processName).font(.title3).textSelection(.enabled)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 9) {
                    detail("Project", port.projectName)
                    detail("PID", String(port.pid))
                    detail("Address", port.endpoint)
                    detail("Family", port.addressFamily.rawValue)
                    detail("User", port.user)
                    detail("Parent PID", port.parentPID.map(String.init))
                    detail("Working Directory", port.workingDirectory)
                    detail("Executable", port.executablePath)
                    detail("Command", port.command)
                }

                Divider()
                actionButtons
                Divider()
                HStack {
                    Button("Terminate", role: .destructive) { confirm(force: false) }
                    Button("Force Kill", role: .destructive) { confirm(force: true) }
                    Spacer()
                    if state.terminatingPIDs.contains(port.pid) { ProgressView().controlSize(.small) }
                }
                .disabled(state.terminatingPIDs.contains(port.pid))
            }
            .padding(16)
        }
        .navigationTitle("Port \(port.port)")
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

    @ViewBuilder private func detail(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            GridRow {
                Text(label).font(.caption).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                Text(value).font(.callout).textSelection(.enabled).lineLimit(4)
            }
        }
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { browser.open(port: port) } label: { Label("Open in Browser", systemImage: "safari") }
            Button { clipboard.copy("http://localhost:\(port.port)") } label: { Label("Copy localhost URL", systemImage: "link") }
            Menu("Copy") {
                Button("Port") { clipboard.copy(String(port.port)) }
                Button("PID") { clipboard.copy(String(port.pid)) }
                Button("Process Name") { clipboard.copy(port.processName) }
                if let cwd = port.workingDirectory { Button("Working Directory") { clipboard.copy(cwd) } }
                Button("Full Process Information") { clipboard.copy(port.fullDescription) }
            }
            if let cwd = port.workingDirectory {
                Button { browser.reveal(directory: cwd) } label: { Label("Reveal Project in Finder", systemImage: "folder") }
            }
        }
        .buttonStyle(.link)
    }

    private func confirm(force: Bool) {
        pendingForce = force
        showsConfirmation = true
    }
}
