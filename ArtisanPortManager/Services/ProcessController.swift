import Darwin
import Foundation
@preconcurrency import OSLog

protocol ProcessSignaling: Sendable {
    func send(signal: Int32, to pid: pid_t) throws
    func exists(pid: pid_t) -> Bool
}

enum SignalError: Error, Equatable { case permissionDenied, noSuchProcess, other(Int32) }

struct DarwinProcessSignaler: ProcessSignaling {
    func send(signal: Int32, to pid: pid_t) throws {
        guard Darwin.kill(pid, signal) == 0 else {
            switch errno {
            case EPERM: throw SignalError.permissionDenied
            case ESRCH: throw SignalError.noSuchProcess
            default: throw SignalError.other(errno)
            }
        }
    }

    func exists(pid: pid_t) -> Bool {
        Darwin.kill(pid, 0) == 0 || errno == EPERM
    }
}

protocol ProcessControlling: Sendable {
    func terminate(_ process: ListeningPort) async -> ProcessTerminationResult
    func forceKill(_ process: ListeningPort) async -> ProcessTerminationResult
}

struct ProcessController: ProcessControlling {
    let signaler: any ProcessSignaling
    let inspector: any ProcessInspecting
    private let logger = Logger(subsystem: "com.artisan.portmanager", category: "process-controller")

    init(signaler: any ProcessSignaling = DarwinProcessSignaler(),
         inspector: any ProcessInspecting = ProcessInspector()) {
        self.signaler = signaler
        self.inspector = inspector
    }

    func terminate(_ process: ListeningPort) async -> ProcessTerminationResult {
        await signal(SIGTERM, process: process, timeout: .seconds(2))
    }

    func forceKill(_ process: ListeningPort) async -> ProcessTerminationResult {
        await signal(SIGKILL, process: process, timeout: .seconds(1))
    }

    private func signal(_ value: Int32, process: ListeningPort,
                        timeout: Duration) async -> ProcessTerminationResult {
        guard process.pid != getpid() else { return .refusedSelfTermination }
        guard signaler.exists(pid: process.pid) else { return .noLongerRunning }

        // ps comm is a stronger identity than lsof's sometimes-truncated command field.
        if let expected = process.executablePath,
           let current = await inspector.currentName(pid: process.pid), current != expected {
            logger.warning("Refusing signal because PID \(process.pid) changed identity")
            return .identityChanged
        }

        do {
            try signaler.send(signal: value, to: process.pid)
        } catch SignalError.permissionDenied { return .permissionDenied
        } catch SignalError.noSuchProcess { return .noLongerRunning
        } catch { return .failed("The signal could not be sent: \(error.localizedDescription)") }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if !signaler.exists(pid: process.pid) { return .succeeded }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return signaler.exists(pid: process.pid)
            ? .failed(value == SIGTERM
                ? "The process did not exit after SIGTERM. You can use Force Kill if needed."
                : "The process is still present after SIGKILL.")
            : .succeeded
    }
}
