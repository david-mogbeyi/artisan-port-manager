import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("General") {
                Toggle("Auto Refresh", isOn: $settings.autoRefresh)
                Picker("Refresh Interval", selection: $settings.refreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("3 seconds").tag(3.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                .disabled(!settings.autoRefresh)
                Toggle("Show Other Users’ Processes", isOn: $settings.showSystemProcesses)
                Toggle("Check Port Reachability", isOn: $settings.probeReachability)
                Text("Probes each listening port on loopback to detect whether it serves HTTP, HTTPS, or only accepts TCP.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 320)
        .navigationTitle("Artisan Port Manager")
    }
}
