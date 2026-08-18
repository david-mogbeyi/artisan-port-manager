import Foundation
@preconcurrency import OSLog

protocol PortScanning: Sendable { func scan() async throws -> [ListeningPort] }

struct PortScanner: PortScanning {
    let runner: any CommandRunning
    let inspector: any ProcessInspecting
    private let parser = LsofParser()
    private let logger = Logger(subsystem: "com.artisan.portmanager", category: "port-scanner")

    init(runner: any CommandRunning = CommandRunner(), inspector: (any ProcessInspecting)? = nil) {
        self.runner = runner
        self.inspector = inspector ?? ProcessInspector(runner: runner)
    }

    func scan() async throws -> [ListeningPort] {
        let lsof = URL(fileURLWithPath: "/usr/sbin/lsof")
        guard FileManager.default.isExecutableFile(atPath: lsof.path) else { throw PortManagerError.scannerUnavailable }
        let result = try await runner.run(executable: lsof,
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcuPnT"])
        // lsof returns 1 when no files match; that is a valid empty state.
        guard result.exitCode == 0 || (result.exitCode == 1 && result.stdout.isEmpty) else {
            logger.error("lsof failed with status \(result.exitCode): \(result.stderr, privacy: .public)")
            throw PortManagerError.commandFailed("lsof exited with status \(result.exitCode).")
        }
        let sockets = parser.parse(result.stdout).filter { $0.pid != getpid() }
        let metadata = await inspector.inspect(pids: Set(sockets.map(\.pid)))
        return sockets.map { socket in
            let info = metadata[socket.pid]
            return ListeningPort(port: socket.port, pid: socket.pid,
                processName: socket.processName, executablePath: info?.executablePath,
                command: info?.command, user: info?.user ?? socket.userID,
                workingDirectory: info?.workingDirectory, parentPID: info?.parentPID,
                address: socket.address, addressFamily: socket.addressFamily)
        }.sorted { ($0.port, $0.processName, $0.pid) < ($1.port, $1.processName, $1.pid) }
    }
}
