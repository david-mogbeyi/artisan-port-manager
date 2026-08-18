import SwiftUI

@main
struct ArtisanPortManagerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: state)
        } label: {
            Label("Artisan Port Manager", systemImage: "network")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: state.settings)
        }
    }
}
