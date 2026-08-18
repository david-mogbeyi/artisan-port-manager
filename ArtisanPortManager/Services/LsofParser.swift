import Foundation

struct DiscoveredSocket: Sendable, Hashable {
    let pid: pid_t
    let processName: String
    let userID: String?
    let port: Int
    let address: String?
    let addressFamily: AddressFamily
}

struct LsofParser {
    func parse(_ output: String) -> [DiscoveredSocket] {
        var pid: pid_t?
        var command = "Unknown"
        var userID: String?
        var family: AddressFamily = .unknown
        var result: [DiscoveredSocket] = []

        for rawLine in output.split(whereSeparator: { $0.isNewline }) {
            let line = String(rawLine)
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = pid_t(value); command = "Unknown"; userID = nil
            case "c": command = value
            case "u": userID = value
            case "P": family = value == "TCP" ? .unknown : family
            case "n":
                guard let pid, let endpoint = parseEndpoint(value) else { continue }
                result.append(DiscoveredSocket(pid: pid, processName: command,
                    userID: userID, port: endpoint.port, address: endpoint.address,
                    addressFamily: endpoint.family))
                family = .unknown
            default: continue
            }
        }

        // The product's primary unit is a process listening on a port. A process often
        // owns parallel IPv4 and IPv6 sockets for the same listener, so collapse those
        // into one row while preserving separate rows for different PIDs or ports.
        let grouped = Dictionary(grouping: result) { "\($0.pid):\($0.port)" }
        return grouped.values.compactMap { sockets in
            sockets.sorted(by: isPreferredRepresentative).first
        }.sorted { ($0.port, $0.pid) < ($1.port, $1.pid) }
    }

    private func isPreferredRepresentative(_ lhs: DiscoveredSocket, _ rhs: DiscoveredSocket) -> Bool {
        func rank(_ socket: DiscoveredSocket) -> Int {
            let wildcard = socket.address == "*" || socket.address == "0.0.0.0" || socket.address == "::"
            if !wildcard && socket.addressFamily == .ipv4 { return 0 }
            if !wildcard && socket.addressFamily == .ipv6 { return 1 }
            if socket.addressFamily == .ipv4 { return 2 }
            return 3
        }
        let lhsRank = rank(lhs)
        let rhsRank = rank(rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return (lhs.address ?? "") < (rhs.address ?? "")
    }

    private func parseEndpoint(_ value: String) -> (address: String?, port: Int, family: AddressFamily)? {
        let cleaned = value.components(separatedBy: "->").first ?? value
        if cleaned.hasPrefix("[") {
            guard let close = cleaned.lastIndex(of: "]"),
                  cleaned.index(after: close) < cleaned.endIndex,
                  cleaned[cleaned.index(after: close)] == ":",
                  let port = Int(cleaned[cleaned.index(close, offsetBy: 2)...]),
                  (1...65535).contains(port) else { return nil }
            let address = String(cleaned[cleaned.index(after: cleaned.startIndex)..<close])
            return (address, port, .ipv6)
        }
        guard let colon = cleaned.lastIndex(of: ":"),
              let port = Int(cleaned[cleaned.index(after: colon)...]),
              (1...65535).contains(port) else { return nil }
        let address = String(cleaned[..<colon])
        let family: AddressFamily = address.contains(":") ? .ipv6 : .ipv4
        return (address.isEmpty ? nil : address, port, family)
    }
}
