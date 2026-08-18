import Darwin
import Foundation
import XCTest
@testable import ArtisanPortManager

private final class FakeSignaler: ProcessSignaling, @unchecked Sendable {
    private let lock = NSLock()
    private var running = true
    var sentSignals: [Int32] = []
    var error: SignalError?

    func send(signal: Int32, to pid: pid_t) throws {
        lock.lock(); defer { lock.unlock() }
        if let error { throw error }
        sentSignals.append(signal)
        running = false
    }

    func exists(pid: pid_t) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }
}

private struct FakeInspector: ProcessInspecting {
    let name: String?
    func inspect(pids: Set<pid_t>) async -> [pid_t: ProcessMetadata] { [:] }
    func currentName(pid: pid_t) async -> String? { name }
}

final class ProcessControllerTests: XCTestCase {
    private func port(executable: String = "/usr/local/bin/node") -> ListeningPort {
        ListeningPort(port: 3000, pid: 42_424, processName: "node",
            executablePath: executable, command: "node server.js", user: "dev",
            workingDirectory: nil, parentPID: nil, address: "*", addressFamily: .ipv4)
    }

    func testTerminateSendsSIGTERM() async {
        let signaler = FakeSignaler()
        let controller = ProcessController(signaler: signaler, inspector: FakeInspector(name: "/usr/local/bin/node"))
        let result = await controller.terminate(port())
        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(signaler.sentSignals, [SIGTERM])
    }

    func testForceKillSendsSIGKILL() async {
        let signaler = FakeSignaler()
        let controller = ProcessController(signaler: signaler, inspector: FakeInspector(name: "/usr/local/bin/node"))
        let result = await controller.forceKill(port())
        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(signaler.sentSignals, [SIGKILL])
    }

    func testRefusesChangedPIDIdentity() async {
        let signaler = FakeSignaler()
        let controller = ProcessController(signaler: signaler, inspector: FakeInspector(name: "/usr/bin/python3"))
        let result = await controller.terminate(port())
        XCTAssertEqual(result, .identityChanged)
        XCTAssertTrue(signaler.sentSignals.isEmpty)
    }

    func testPermissionErrorIsFriendly() async {
        let signaler = FakeSignaler()
        signaler.error = .permissionDenied
        let controller = ProcessController(signaler: signaler, inspector: FakeInspector(name: "/usr/local/bin/node"))
        let result = await controller.terminate(port())
        XCTAssertEqual(result, .permissionDenied)
    }
}
