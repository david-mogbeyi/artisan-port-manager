import XCTest
@testable import ArtisanPortManager

@MainActor
final class BookmarkTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: PortBookmarkStore!
    private let suiteName = "BookmarkTests"

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
        store = PortBookmarkStore(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        try await super.tearDown()
    }

    private func identity(_ port: Int, _ path: String? = "/usr/local/bin/node") -> PortIdentity {
        PortIdentity(port: port, executablePath: path)
    }

    // MARK: - Aliases

    func testAliasRoundTrips() {
        store.setAlias("Artisan DB", for: identity(5432))
        XCTAssertEqual(store.alias(for: identity(5432)), "Artisan DB")
    }

    func testAliasIsTrimmedAndBlankClearsIt() {
        store.setAlias("  Padded  ", for: identity(3000))
        XCTAssertEqual(store.alias(for: identity(3000)), "Padded")

        store.setAlias("   ", for: identity(3000))
        XCTAssertNil(store.alias(for: identity(3000)))
    }

    func testAliasIsScopedToTheOwningExecutable() {
        store.setAlias("Node Dev Server", for: identity(3000, "/usr/local/bin/node"))
        XCTAssertNil(store.alias(for: identity(3000, "/usr/bin/python3")))
    }

    func testAliasSurvivesRestartOfTheSameService() {
        // A restarted server keeps its port and executable but gets a new PID, so the
        // alias must still resolve.
        store.setAlias("API", for: identity(8080))
        let reopened = PortBookmarkStore(defaults: defaults)
        XCTAssertEqual(reopened.alias(for: identity(8080)), "API")
    }

    func testAliasFallsBackToPortWhenExecutableIsUnknown() {
        store.setAlias("Mystery", for: identity(9000, nil))
        XCTAssertEqual(store.alias(for: identity(9000, nil)), "Mystery")
        // A later scan that does resolve the executable still finds the alias.
        XCTAssertEqual(store.alias(for: identity(9000, "/usr/sbin/httpd")), "Mystery")
    }

    // MARK: - Favorites

    func testFavoriteTogglesBothWays() {
        XCTAssertFalse(store.isFavorite(identity(5432)))
        store.toggleFavorite(identity(5432))
        XCTAssertTrue(store.isFavorite(identity(5432)))
        store.toggleFavorite(identity(5432))
        XCTAssertFalse(store.isFavorite(identity(5432)))
    }

    func testFavoritesPersistAcrossLaunches() {
        store.toggleFavorite(identity(5432))
        let reopened = PortBookmarkStore(defaults: defaults)
        XCTAssertTrue(reopened.isFavorite(identity(5432)))
    }

    func testFavoritingOnePortDoesNotAffectAnother() {
        store.toggleFavorite(identity(3000))
        XCTAssertFalse(store.isFavorite(identity(3001)))
    }

    // MARK: - Search

    func testAliasIsSearchable() {
        let port = ListeningPort(port: 5432, pid: 685, processName: "postgres",
            executablePath: "/usr/local/bin/postgres", command: nil, user: "developer",
            workingDirectory: nil, parentPID: nil, address: "127.0.0.1", addressFamily: .ipv4)
        XCTAssertTrue(port.matches("artisan", alias: "Artisan DB"))
        XCTAssertFalse(port.matches("artisan"))
        // Existing fields keep matching when an alias is present.
        XCTAssertTrue(port.matches("postgres", alias: "Artisan DB"))
    }
}
