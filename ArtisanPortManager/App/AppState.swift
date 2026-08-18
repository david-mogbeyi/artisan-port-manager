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
    /// Probe results keyed by port number, retained across refreshes so rows do not
    /// flicker back to "unknown" on every scan.
    @Published private(set) var reachability: [Int: PortReachability] = [:]

    let settings: SettingsStore
    let bookmarks: PortBookmarkStore
    private let scanner: any PortScanning
    private let controller: any ProcessControlling
    private let prober: any ReachabilityProbing
    private var probeTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.artisan.portmanager", category: "ui")

    init(scanner: any PortScanning = PortScanner(),
         controller: any ProcessControlling = ProcessController(),
         settings: SettingsStore? = nil,
         bookmarks: PortBookmarkStore? = nil,
         prober: (any ReachabilityProbing)? = nil) {
        self.scanner = scanner
        self.controller = controller
        self.settings = settings ?? SettingsStore()
        self.bookmarks = bookmarks ?? PortBookmarkStore()
        self.prober = prober ?? ReachabilityProber()
    }

    func reachability(for port: ListeningPort) -> PortReachability {
        reachability[port.port] ?? .unknown
    }

    var filteredPorts: [ListeningPort] {
        ports.filter { port in
            let allowed = settings.showSystemProcesses || port.user == nil || port.user == NSUserName()
            return allowed && port.matches(searchText, alias: alias(for: port))
        }
    }

    func alias(for port: ListeningPort) -> String? {
        bookmarks.alias(for: PortIdentity(port))
    }

    func isFavorite(_ port: ListeningPort) -> Bool {
        bookmarks.isFavorite(PortIdentity(port))
    }

    func toggleFavorite(_ port: ListeningPort) {
        bookmarks.toggleFavorite(PortIdentity(port))
    }

    func setAlias(_ alias: String?, for port: ListeningPort) {
        bookmarks.setAlias(alias, for: PortIdentity(port))
    }

    /// Filtered ports clustered by owning process so a single process listening on many
    /// ports occupies one row instead of repeating itself down the list. Groups containing
    /// a favorite are surfaced first, preserving the scanner's ordering within each band.
    var filteredPortGroups: [PortGroup] {
        let groups = PortGroup.group(filteredPorts)
        let favorites = groups.filter { $0.ports.contains(where: isFavorite) }
        let rest = groups.filter { !$0.ports.contains(where: isFavorite) }
        return favorites + rest
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            ports = try await scanner.scan()
            errorMessage = nil
            probeReachability()
        } catch {
            logger.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Probes every visible port, replacing any in-flight probe from a previous scan.
    ///
    /// Results for ports that are no longer listening are dropped so the cache cannot grow
    /// without bound over a long session.
    private func probeReachability() {
        probeTask?.cancel()
        guard settings.probeReachability else {
            reachability.removeAll()
            return
        }

        let live = Set(ports.map(\.port))
        reachability = reachability.filter { live.contains($0.key) }
        for port in live where reachability[port] == nil {
            reachability[port] = .probing
        }

        let prober = prober
        probeTask = Task { [weak self] in
            await withTaskGroup(of: (Int, PortReachability).self) { group in
                for port in live.sorted() {
                    group.addTask { (port, await prober.probe(port: port)) }
                }
                for await (port, result) in group {
                    guard !Task.isCancelled else { return }
                    self?.reachability[port] = result
                }
            }
        }
    }

    /// Re-probes a single port on demand, for the detail view's refresh control.
    func probe(_ port: ListeningPort) async {
        reachability[port.port] = .probing
        let result = await prober.probe(port: port.port)
        reachability[port.port] = result
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
