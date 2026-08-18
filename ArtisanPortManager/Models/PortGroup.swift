import Foundation

/// A process and every port it listens on.
///
/// `lsof` reports one row per listening socket, so a process such as a language-server
/// host legitimately produces many rows. Those are distinct listeners, not duplicates —
/// collapsing them into a single port would hide real sockets and make termination
/// ambiguous. Instead the list groups them under their owning process, so the repetition
/// disappears from the UI while every port stays individually reachable.
struct PortGroup: Identifiable, Sendable, Hashable {
    let pid: pid_t
    let ports: [ListeningPort]

    var id: pid_t { pid }

    /// The row shown when the group is collapsed; also the target for single-port groups.
    var representative: ListeningPort { ports[0] }

    var isMultiPort: Bool { ports.count > 1 }
    var processName: String { representative.processName }
    var projectName: String? { representative.projectName }

    /// "3000, 3001, 5432" — capped so a process with many listeners cannot overflow the row.
    func portSummary(limit: Int = 4) -> String {
        let shown = ports.prefix(limit).map { String($0.port) }.joined(separator: ", ")
        let remainder = ports.count - min(limit, ports.count)
        return remainder > 0 ? "\(shown) +\(remainder) more" : shown
    }

    /// Groups ports by owning process, preserving the incoming sort order for both the
    /// groups and the ports inside each group.
    static func group(_ ports: [ListeningPort]) -> [PortGroup] {
        var order: [pid_t] = []
        var buckets: [pid_t: [ListeningPort]] = [:]
        for port in ports {
            if buckets[port.pid] == nil { order.append(port.pid) }
            buckets[port.pid, default: []].append(port)
        }
        return order.compactMap { pid in
            guard let owned = buckets[pid], !owned.isEmpty else { return nil }
            return PortGroup(pid: pid, ports: owned)
        }
    }
}
