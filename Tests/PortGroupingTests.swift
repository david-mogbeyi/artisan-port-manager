import XCTest
@testable import ArtisanPortManager

final class PortGroupingTests: XCTestCase {
    private func port(_ number: Int, pid: pid_t, name: String = "node",
                      cwd: String? = nil) -> ListeningPort {
        ListeningPort(port: number, pid: pid, processName: name, executablePath: nil,
                      command: nil, user: "developer", workingDirectory: cwd,
                      parentPID: nil, address: "127.0.0.1", addressFamily: .ipv4)
    }

    func testCollapsesOneProcessWithManyPortsIntoASingleGroup() {
        // Mirrors the real "Code Helper (Plugin)" case: one PID, four distinct listeners.
        let ports = [port(40973, pid: 1674, name: "Code Helper (Plugin)"),
                     port(47821, pid: 1674, name: "Code Helper (Plugin)"),
                     port(47822, pid: 1674, name: "Code Helper (Plugin)"),
                     port(50561, pid: 1674, name: "Code Helper (Plugin)")]
        let groups = PortGroup.group(ports)
        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].isMultiPort)
        XCTAssertEqual(groups[0].pid, 1674)
        XCTAssertEqual(groups[0].ports.count, 4)
    }

    func testNoListenerIsLostByGrouping() {
        let ports = [port(3000, pid: 10), port(3001, pid: 10), port(5432, pid: 20)]
        let groups = PortGroup.group(ports)
        let flattened = groups.flatMap(\.ports).map(\.port).sorted()
        XCTAssertEqual(flattened, [3000, 3001, 5432])
    }

    func testDistinctProcessesStayInSeparateGroups() {
        let groups = PortGroup.group([port(3000, pid: 10), port(3000, pid: 11)])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.map(\.pid), [10, 11])
        XCTAssertTrue(groups.allSatisfy { !$0.isMultiPort })
    }

    func testSinglePortProcessIsNotTreatedAsAGroup() {
        let groups = PortGroup.group([port(5432, pid: 685, name: "postgres")])
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups[0].isMultiPort)
        XCTAssertEqual(groups[0].representative.port, 5432)
    }

    func testGroupAndPortOrderingIsPreserved() {
        let groups = PortGroup.group([port(3000, pid: 10), port(5432, pid: 20), port(3001, pid: 10)])
        XCTAssertEqual(groups.map(\.pid), [10, 20])
        XCTAssertEqual(groups[0].ports.map(\.port), [3000, 3001])
    }

    func testPortSummaryTruncatesLongPortLists() {
        let ports = (1...7).map { port(3000 + $0, pid: 42) }
        let summary = PortGroup.group(ports)[0].portSummary(limit: 4)
        XCTAssertEqual(summary, "3001, 3002, 3003, 3004 +3 more")
    }

    func testPortSummaryOmitsRemainderWhenAllPortsFit() {
        let groups = PortGroup.group([port(3000, pid: 10), port(3001, pid: 10)])
        XCTAssertEqual(groups[0].portSummary(limit: 4), "3000, 3001")
    }

    func testEmptyInputProducesNoGroups() {
        XCTAssertTrue(PortGroup.group([]).isEmpty)
    }
}
