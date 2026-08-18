import AppKit
import Foundation

struct BrowserService {
    func open(port: ListeningPort) {
        guard let url = port.localhostURL else { return }
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
