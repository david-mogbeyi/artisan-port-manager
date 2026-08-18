import Foundation

/// What a listening socket actually answers when spoken to.
///
/// A socket appearing in `lsof` only proves something is bound to the port — not that it
/// serves HTTP, or that it is healthy. Probing distinguishes a working web server from a
/// database, a gRPC service, or a process that is bound but wedged.
enum PortReachability: Sendable, Hashable {
    /// Not probed yet, or probing is disabled.
    case unknown
    /// A probe is in flight.
    case probing
    /// Answered an HTTP request over the given scheme, with the status code it returned.
    case http(scheme: String, statusCode: Int)
    /// Accepted a TCP connection but did not answer HTTP — a database, for example.
    case tcpOnly
    /// Refused the connection or timed out despite holding the socket.
    case unreachable

    /// Scheme to use when opening the port in a browser. Falls back to `http` so the
    /// action behaves as it always did before probing resolves.
    var preferredScheme: String {
        if case let .http(scheme, _) = self { return scheme }
        return "http"
    }

    /// Whether opening this port in a browser is likely to be useful.
    var isWebServer: Bool {
        if case .http = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .unknown: return "Listening"
        case .probing: return "Checking…"
        case let .http(scheme, status): return "\(scheme.uppercased()) \(status)"
        case .tcpOnly: return "TCP only"
        case .unreachable: return "Not responding"
        }
    }

    var detailLabel: String {
        switch self {
        case .unknown: return "Not checked"
        case .probing: return "Checking…"
        case let .http(scheme, status): return "Serving \(scheme.uppercased()) · HTTP \(status)"
        case .tcpOnly: return "Accepts TCP connections, does not speak HTTP"
        case .unreachable: return "Holding the socket but refusing connections"
        }
    }
}
