import Foundation

/// A stable way to refer to "the same port" across restarts.
///
/// PIDs churn every time a server restarts, so they cannot anchor a user's alias or
/// favorite. The port number plus the executable that owns it survives restarts of the
/// same service while still distinguishing two different tools that reuse a port at
/// different times.
struct PortIdentity: Hashable, Sendable {
    let port: Int
    let executablePath: String?

    init(port: Int, executablePath: String?) {
        self.port = port
        self.executablePath = executablePath
    }

    init(_ port: ListeningPort) {
        self.init(port: port.port, executablePath: port.executablePath)
    }

    /// Key used for persistence. The executable is included so that, say, a Node dev
    /// server and a Postgres instance that both used 5432 do not share one alias.
    var storageKey: String { "\(port)|\(executablePath ?? "")" }

    /// Ports the user pinned or renamed before an executable path was resolvable fall
    /// back to matching on the port number alone.
    var portOnlyKey: String { "\(port)|" }
}
