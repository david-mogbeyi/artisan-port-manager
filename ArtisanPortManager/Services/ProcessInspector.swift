import Darwin
import Foundation

protocol ProcessInspecting: Sendable {
    func inspect(pids: Set<pid_t>) async -> [pid_t: ProcessMetadata]
    func currentName(pid: pid_t) async -> String?
}

struct ProcessInspector: ProcessInspecting {
    let runner: any CommandRunning

    init(runner: any CommandRunning = CommandRunner()) { self.runner = runner }

    func inspect(pids: Set<pid_t>) async -> [pid_t: ProcessMetadata] {
        guard !pids.isEmpty else { return [:] }
        let list = pids.sorted().map(String.init).joined(separator: ",")
        async let processResult = try? runner.run(
            executable: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-ww", "-p", list, "-o", "pid=", "-o", "ppid=", "-o", "user=", "-o", "command="])
        async let cwdResult = try? runner.run(
            executable: URL(fileURLWithPath: "/usr/sbin/lsof"),
            arguments: ["-a", "-p", list, "-d", "cwd", "-Fn"])

        let processRows = await processResult
        let cwdRows = await cwdResult
        let cwdByPID = parseCWD(cwdRows?.stdout ?? "")
        var metadata: [pid_t: ProcessMetadata] = [:]
        for line in (processRows?.stdout ?? "").split(whereSeparator: { $0.isNewline }) {
            let fields = line.split(maxSplits: 3, whereSeparator: { $0.isWhitespace })
            guard fields.count >= 3, let pid = pid_t(fields[0]) else { continue }
            let ppid = pid_t(fields[1])
            let user = String(fields[2])
            let executable = executablePath(pid: pid)
            let command = fields.count == 4 ? String(fields[3]) : executable
            metadata[pid] = ProcessMetadata(pid: pid, parentPID: ppid, user: user,
                executablePath: executable, command: command, workingDirectory: cwdByPID[pid])
        }
        return metadata
    }

    func currentName(pid: pid_t) async -> String? {
        executablePath(pid: pid)
    }

    private func executablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    private func parseCWD(_ output: String) -> [pid_t: String] {
        var currentPID: pid_t?
        var values: [pid_t: String] = [:]
        for line in output.split(whereSeparator: { $0.isNewline }).map(String.init) {
            if line.first == "p" { currentPID = pid_t(line.dropFirst()) }
            if line.first == "n", let currentPID { values[currentPID] = String(line.dropFirst()) }
        }
        return values
    }
}
