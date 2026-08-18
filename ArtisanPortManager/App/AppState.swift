import AppKit
import Foundation
import OSLog

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var ports: [ListeningPort] = []
    @Published var searchText = ""
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var terminatingPIDs: Set<pid_t> = []

    let settings: SettingsStore
    private let scanner: any PortScanning
    private let controller: any ProcessControlling
    private let logger = Logger(subsystem: "com.artisan.portmanager", category: "ui")

    init(scanner: any PortScanning = PortScanner(),
         controller: any ProcessControlling = ProcessController(),
         settings: SettingsStore? = nil) {
        self.scanner = scanner
        self.controller = controller
        self.settings = settings ?? SettingsStore()
    }

    var filteredPorts: [ListeningPort] {
        ports.filter { port in
            let allowed = settings.showSystemProcesses || port.user == nil || port.user == NSUserName()
            return allowed && port.matches(searchText)
        }
    }

    /// Filtered ports clustered by owning process so a single process listening on many
    /// ports occupies one row instead of repeating itself down the list.
    var filteredPortGroups: [PortGroup] { PortGroup.group(filteredPorts) }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            ports = try await scanner.scan()
            errorMessage = nil
        } catch {
            logger.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func terminate(_ port: ListeningPort, force: Bool) async {
        guard !terminatingPIDs.contains(port.pid) else { return }
        terminatingPIDs.insert(port.pid)
        defer { terminatingPIDs.remove(port.pid) }
        let result = force ? await controller.forceKill(port) : await controller.terminate(port)
        switch result {
        case .succeeded, .noLongerRunning:
            ports.removeAll { $0.pid == port.pid }
            statusMessage = "\(force ? "Force killed" : "Terminated") \(port.processName) on port \(port.port)."
            try? await Task.sleep(for: .milliseconds(250))
            await refresh()
        default:
            errorMessage = result.message
        }
    }
}
