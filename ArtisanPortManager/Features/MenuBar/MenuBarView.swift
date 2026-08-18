import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var state: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "network")
                    Text("Artisan Port Manager").font(.headline)
                    Spacer()
                    if state.isRefreshing { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)

                Divider()
                TextField("Search ports, processes, projects…", text: $state.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(10)
                Divider()

                PortListView(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let message = state.statusMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).padding(.horizontal, 12).padding(.vertical, 5)
                }
                if let error = state.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.caption).lineLimit(2)
                        Spacer()
                        Button("Dismiss") { state.errorMessage = nil }.buttonStyle(.link)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.orange.opacity(0.08))
                }
                Divider()
                HStack {
                    Button { Task { await state.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        .keyboardShortcut("r")
                        .disabled(state.isRefreshing)
                    SettingsLink { Label("Settings", systemImage: "gear") }
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 12).padding(.vertical, 9)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 390, height: 540)
        .task(id: "\(state.settings.autoRefresh)-\(state.settings.refreshInterval)") {
            await state.refresh()
            guard state.settings.autoRefresh else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(state.settings.refreshInterval))
                if !Task.isCancelled { await state.refresh() }
            }
        }
    }
}
