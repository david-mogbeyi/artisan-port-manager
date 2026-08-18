import AppKit
import Foundation

struct BrowserService {
    /// Opens the port in the default browser. The scheme comes from the reachability
    /// probe when one has resolved, so an HTTPS-only dev server no longer opens on
    /// `http://` and fails; it falls back to `http` when the port has not been probed.
    func open(port: ListeningPort, reachability: PortReachability = .unknown) {
        guard let url = port.url(scheme: reachability.preferredScheme) else { return }
        NSWorkspace.shared.open(url)
    }

    func reveal(directory: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: directory)])
    }
}

struct ClipboardService {
    func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
