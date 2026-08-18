import XCTest
@testable import ArtisanPortManager

final class ReachabilityTests: XCTestCase {
    // MARK: - Scheme selection

    func testHTTPSPortOpensOverHTTPS() {
        // The known limitation this feature fixes: Open used to assume http:// always.
        let state = PortReachability.http(scheme: "https", statusCode: 200)
        XCTAssertEqual(state.preferredScheme, "https")
    }

    func testNonWebAndUnprobedPortsFallBackToHTTP() {
        for state in [PortReachability.unknown, .probing, .tcpOnly, .unreachable] {
            XCTAssertEqual(state.preferredScheme, "http",
                           "Expected http fallback for \(state)")
        }
    }

    func testOnlyHTTPPortsCountAsWebServers() {
        XCTAssertTrue(PortReachability.http(scheme: "http", statusCode: 200).isWebServer)
        // An error status still proves a web server is answering.
        XCTAssertTrue(PortReachability.http(scheme: "http", statusCode: 500).isWebServer)
        XCTAssertFalse(PortReachability.tcpOnly.isWebServer)
        XCTAssertFalse(PortReachability.unreachable.isWebServer)
        XCTAssertFalse(PortReachability.unknown.isWebServer)
    }

    func testURLUsesTheGivenScheme() {
        let port = ListeningPort(port: 8443, pid: 1, processName: "node",
            executablePath: nil, command: nil, user: nil, workingDirectory: nil,
            parentPID: nil, address: "127.0.0.1", addressFamily: .ipv4)
        XCTAssertEqual(port.url(scheme: "https")?.absoluteString, "https://localhost:8443")
        XCTAssertEqual(port.localhostURL?.absoluteString, "http://localhost:8443")
    }

    // MARK: - Labels

    func testLabelsDistinguishTheStates() {
        XCTAssertEqual(PortReachability.http(scheme: "https", statusCode: 204).label, "HTTPS 204")
        XCTAssertEqual(PortReachability.tcpOnly.label, "TCP only")
        XCTAssertEqual(PortReachability.unreachable.label, "Not responding")
        XCTAssertEqual(PortReachability.probing.label, "Checking…")
        XCTAssertEqual(PortReachability.unknown.label, "Listening")
    }

    // MARK: - Probe behaviour against a real socket

    func testProbeDetectsAPortThatNothingIsListeningOn() async throws {
        // Bind and immediately release a port so it is almost certainly free.
        let free = try Self.temporarilyBoundPort()
        let result = await ReachabilityProber(timeout: 0.5).probe(port: free)
        XCTAssertEqual(result, .unreachable)
    }

    func testProbeReportsTCPOnlyForANonHTTPListener() async throws {
        let listener = try TCPTestListener()
        defer { listener.stop() }
        let result = await ReachabilityProber(timeout: 2.0).probe(port: listener.port)
        // The socket accepts connections but never speaks HTTP.
        XCTAssertEqual(result, .tcpOnly)
    }

    /// Binds a port, closes it, and returns the number — very likely still free.
    private static func temporarilyBoundPort() throws -> Int {
        let listener = try TCPTestListener()
        let port = listener.port
        listener.stop()
        return port
    }
}
