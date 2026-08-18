import Foundation

enum AddressFamily: String, Sendable, Hashable {
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"
    case unknown = "TCP"
}

struct ListeningPort: Identifiable, Sendable, Hashable {
    let port: Int
    let pid: pid_t
    let processName: String
    let executablePath: String?
    let command: String?
    let user: String?
    let workingDirectory: String?
    let parentPID: pid_t?
    let address: String?
    let addressFamily: AddressFamily

    var id: String { "\(pid):\(port)" }
    var projectName: String? {
        guard let workingDirectory, workingDirectory != "/" else { return nil }
        return URL(fileURLWithPath: workingDirectory).lastPathComponent
    }
    var localhostURL: URL? { URL(string: "http://localhost:\(port)") }
    var endpoint: String {
        guard let address else { return "localhost:\(port)" }
        return addressFamily == .ipv6 ? "[\(address)]:\(port)" : "\(address):\(port)"
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return [String(port), String(pid), processName, projectName, command,
                workingDirectory, user, address]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(needle) }
    }

    var fullDescription: String {
        var lines = [
            "Port: \(port)",
            "URL: http://localhost:\(port)",
            "Process: \(processName)",
            "PID: \(pid)"
        ]
        if let projectName { lines.append("Project: \(projectName)") }
        if let workingDirectory { lines.append("Working Directory: \(workingDirectory)") }
        if let command { lines.append("Command: \(command)") }
        return lines.joined(separator: "\n")
    }
}
