import Foundation

struct ProcessMetadata: Sendable, Equatable {
    let pid: pid_t
    let parentPID: pid_t?
    let user: String?
    let executablePath: String?
    let command: String?
    let workingDirectory: String?
}

enum ProcessTerminationResult: Sendable, Equatable {
    case succeeded
    case noLongerRunning
    case permissionDenied
    case identityChanged
    case refusedSelfTermination
    case failed(String)

    var message: String {
        switch self {
        case .succeeded: return "The process was terminated."
        case .noLongerRunning: return "The process has already exited."
        case .permissionDenied: return "Artisan Port Manager does not have permission to terminate this process."
        case .identityChanged: return "The PID now belongs to a different process. Refresh and try again."
        case .refusedSelfTermination: return "Artisan Port Manager cannot terminate itself."
        case .failed(let detail): return detail
        }
    }
}

enum PortManagerError: LocalizedError, Sendable {
    case scannerUnavailable
    case commandFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .scannerUnavailable: return "Unable to find the macOS lsof utility."
        case .commandFailed(let detail): return "Unable to scan listening ports. \(detail)"
        case .invalidOutput: return "The listening-port data could not be read."
        }
    }
}
