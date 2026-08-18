import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let autoRefresh = "autoRefresh"
        static let refreshInterval = "refreshInterval"
        static let showSystemProcesses = "showSystemProcesses"
    }

    @Published var autoRefresh: Bool { didSet { defaults.set(autoRefresh, forKey: Key.autoRefresh) } }
    @Published var refreshInterval: Double { didSet { defaults.set(refreshInterval, forKey: Key.refreshInterval) } }
    @Published var showSystemProcesses: Bool { didSet { defaults.set(showSystemProcesses, forKey: Key.showSystemProcesses) } }
    @Published private(set) var launchAtLogin: Bool
    @Published var launchAtLoginError: String?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.autoRefresh: true, Key.refreshInterval: 3.0,
                                     Key.showSystemProcesses: false])
        autoRefresh = defaults.bool(forKey: Key.autoRefresh)
        refreshInterval = defaults.double(forKey: Key.refreshInterval)
        showSystemProcesses = defaults.bool(forKey: Key.showSystemProcesses)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = error.localizedDescription
        }
    }
}
