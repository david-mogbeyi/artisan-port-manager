import XCTest
@testable import ArtisanPortManager

final class FilteringTests: XCTestCase {
    private let port = ListeningPort(port: 5173, pid: 48219, processName: "node",
        executablePath: "/opt/homebrew/bin/node", command: "node vite --host",
        user: "developer", workingDirectory: "/Users/developer/Projects/artisan-ui",
        parentPID: 100, address: "127.0.0.1", addressFamily: .ipv4)

    func testSearchesAllUsefulFields() {
        for query in ["5173", "48219", "NODE", "artisan", "vite", "Projects"] {
            XCTAssertTrue(port.matches(query), "Expected a match for \(query)")
        }
        XCTAssertFalse(port.matches("postgres"))
    }

    func testProjectNameAndFormatting() {
        XCTAssertEqual(port.projectName, "artisan-ui")
        XCTAssertTrue(port.fullDescription.contains("Working Directory: /Users/developer/Projects/artisan-ui"))
        XCTAssertEqual(port.localhostURL?.absoluteString, "http://localhost:5173")
    }
}
