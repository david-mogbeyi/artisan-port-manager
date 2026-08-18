import XCTest
@testable import ArtisanPortManager

final class LsofParserTests: XCTestCase {
    func testParsesIPv4IPv6WildcardAndMultiplePorts() {
        let fixture = """
        p123
        cnode
        u501
        f10
        PTCP
        n127.0.0.1:3000
        TST=LISTEN
        f11
        PTCP
        n*:3001
        TST=LISTEN
        p456
        cpostgres
        u501
        f7
        PTCP
        n[::1]:5432
        TST=LISTEN
        """
        let ports = LsofParser().parse(fixture)
        XCTAssertEqual(ports.map(\.port), [3000, 3001, 5432])
        XCTAssertEqual(ports[0].address, "127.0.0.1")
        XCTAssertEqual(ports[0].addressFamily, .ipv4)
        XCTAssertEqual(ports[2].address, "::1")
        XCTAssertEqual(ports[2].addressFamily, .ipv6)
    }

    func testDeduplicatesSamePIDPortAndFamily() {
        let fixture = """
        p123
        cnode
        n*:3000
        n127.0.0.1:3000
        nmalformed
        n127.0.0.1:notaport
        """
        let ports = LsofParser().parse(fixture)
        XCTAssertEqual(ports.count, 1)
        XCTAssertEqual(ports.first?.address, "127.0.0.1")
    }

    func testSameProcessCanExposeMultiplePorts() {
        let ports = LsofParser().parse("p9\ncpython\nn*:8000\nn*:8001\n")
        XCTAssertEqual(ports.map(\.port), [8000, 8001])
        XCTAssertTrue(ports.allSatisfy { $0.pid == 9 })
    }
}
