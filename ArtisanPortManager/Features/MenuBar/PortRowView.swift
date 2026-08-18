import SwiftUI

struct PortRowView: View {
    let port: ListeningPort
    let isTerminating: Bool
    var alias: String?
    var isFavorite = false
    var reachability: PortReachability = .unknown

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                        .accessibilityLabel(reachability.label)
                    Text(String(port.port)).font(.headline.monospacedDigit())
                    if reachability.isWebServer {
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Serves \(reachability.preferredScheme.uppercased())")
                    }
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorite")
                    }
                    Spacer()
                }
                // A user-assigned alias replaces the process name as the row's identity;
                // the process name drops to the caption so nothing is lost.
                Text(alias ?? port.processName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .opacity(isTerminating ? 0.6 : 1)
    }

    /// Green for a healthy web server, blue for a non-HTTP listener such as a database,
    /// orange when the socket is held but refuses connections, grey while probing.
    private var statusColor: Color {
        switch reachability {
        case .http: return .green
        case .tcpOnly: return .blue
        case .unreachable: return .orange
        case .probing: return .gray
        case .unknown: return .green
        }
    }

    private var subtitle: String {
        let context = alias == nil
            ? (port.projectName ?? port.addressFamily.rawValue)
            : port.processName
        return "\(context) · PID \(port.pid)"
    }

    private var iconName: String {
        let name = port.processName.lowercased()
        if name.contains("postgres") || name.contains("redis") || name.contains("mysql") { return "cylinder" }
        if name.contains("docker") { return "shippingbox" }
        if ["node", "python", "ruby", "php", "java"].contains(where: name.contains) { return "terminal" }
        return "gearshape.2"
    }
}
