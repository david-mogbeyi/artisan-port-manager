import Foundation
import Network
@preconcurrency import OSLog

protocol ReachabilityProbing: Sendable {
    func probe(port: Int) async -> PortReachability
}

/// Determines what a listening port actually serves.
///
/// Probes HTTP first because it is the common case for local development, then HTTPS, and
/// finally falls back to a raw TCP connect. The TCP step is what separates "this is a
/// database, not a web server" from "this process is holding the socket but not answering".
struct ReachabilityProber: ReachabilityProbing {
    /// Per-attempt timeout. Kept short because this runs against loopback, where a healthy
    /// server answers in milliseconds, and because the scan refreshes on an interval.
    let timeout: TimeInterval
    private let logger = Logger(subsystem: "com.artisan.portmanager", category: "reachability")

    init(timeout: TimeInterval = 1.5) {
        self.timeout = timeout
    }

    func probe(port: Int) async -> PortReachability {
        for scheme in ["http", "https"] {
            if let status = await httpStatus(scheme: scheme, port: port) {
                return .http(scheme: scheme, statusCode: status)
            }
        }
        return await acceptsTCP(port: port) ? .tcpOnly : .unreachable
    }

    /// Returns the HTTP status code if the port answers HTTP on this scheme.
    ///
    /// Any status counts as success — a 401 or 500 still proves a web server is there,
    /// which is the question being asked.
    private func httpStatus(scheme: String, port: Int) async -> Int? {
        guard let url = URL(string: "\(scheme)://127.0.0.1:\(port)/") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        // Probing must reflect the server's current state, never a cached response.
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        // Local dev servers routinely use self-signed certificates; a TLS trust failure
        // still answers the question "is something serving HTTPS here?".
        let session = URLSession(configuration: configuration,
                                 delegate: LocalhostTrustDelegate(),
                                 delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode
        } catch {
            return nil
        }
    }

    /// Whether a TCP connection can be established at all.
    private func acceptsTCP(port: Int) async -> Bool {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(exactly: port) ?? 0) else {
            return false
        }
        let connection = NWConnection(host: "127.0.0.1", port: endpointPort, using: .tcp)

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    // NWConnection can report several state changes; only the first result wins.
                    let resumed = OSAllocatedUnfairLock(initialState: false)
                    func finish(_ value: Bool) {
                        let shouldResume = resumed.withLock { done -> Bool in
                            guard !done else { return false }
                            done = true
                            return true
                        }
                        if shouldResume { continuation.resume(returning: value) }
                    }
                    connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready: finish(true)
                        case .failed, .cancelled: finish(false)
                        case .waiting: finish(false)
                        default: break
                        }
                    }
                    connection.start(queue: .global(qos: .utility))
                }
            }
            group.addTask { [timeout] in
                try? await Task.sleep(for: .seconds(timeout))
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            connection.cancel()
            return result
        }
    }
}

/// Accepts self-signed certificates on loopback only. This never runs against a remote
/// host — the prober only ever connects to 127.0.0.1.
private final class LocalhostTrustDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == "127.0.0.1",
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}
