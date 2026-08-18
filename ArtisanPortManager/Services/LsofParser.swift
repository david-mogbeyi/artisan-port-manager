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

        // One logical row per PID/port/family. Prefer a specific interface to a wildcard.
        let grouped = Dictionary(grouping: result) { "\($0.pid):\($0.port):\($0.addressFamily.rawValue)" }
        return grouped.values.compactMap { sockets in
            sockets.sorted { lhs, rhs in
                let lhsWildcard = lhs.address == "*" || lhs.address == "0.0.0.0" || lhs.address == "::"
                let rhsWildcard = rhs.address == "*" || rhs.address == "0.0.0.0" || rhs.address == "::"
                return !lhsWildcard && rhsWildcard
            }.first
        }.sorted { ($0.port, $0.pid, $0.addressFamily.rawValue) < ($1.port, $1.pid, $1.addressFamily.rawValue) }
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
