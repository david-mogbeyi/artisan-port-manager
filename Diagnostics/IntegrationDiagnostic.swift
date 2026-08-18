import Darwin
import Foundation

@main
struct IntegrationDiagnostic {
    static func main() async throws {
        setbuf(stdout, nil)
        let port = 48_765
        let listener = Process()
        listener.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        listener.arguments = ["-m", "http.server", String(port), "--bind", "127.0.0.1"]
        listener.standardOutput = FileHandle.nullDevice
        listener.standardError = FileHandle.nullDevice
        try listener.run()
        defer { if listener.isRunning { listener.terminate() } }
        try await Task.sleep(for: .milliseconds(700))

        let scanner = PortScanner()
        let scanned = try await scanner.scan()
        guard let match = scanned.first(where: { $0.port == port && $0.pid == listener.processIdentifier }) else {
            throw DiagnosticError.listenerNotFound
        }
        print("Discovered PID \(match.pid), process \(match.processName), executable \(match.executablePath ?? "unknown")")
        print("Revalidated executable: \(await ProcessInspector().currentName(pid: match.pid) ?? "unknown")")
        let result = await ProcessController().terminate(match)
        guard result == .succeeded || result == .noLongerRunning else {
            throw DiagnosticError.terminationFailed(result.message)
        }
        try await Task.sleep(for: .milliseconds(300))
        let rescanned = try await scanner.scan()
        guard !rescanned.contains(where: { $0.port == port && $0.pid == listener.processIdentifier }) else {
            throw DiagnosticError.listenerStillPresent
        }
        print("PASS: discovered and terminated test listener on port \(port)")
    }
}

private enum DiagnosticError: LocalizedError {
    case listenerNotFound
    case terminationFailed(String)
    case listenerStillPresent

    var errorDescription: String? {
        switch self {
        case .listenerNotFound: return "The temporary listener was not discovered."
        case .terminationFailed(let detail): return detail
        case .listenerStillPresent: return "The listener remained after termination."
        }
    }
}
