import SwiftUI

/// Collapsed header for a process that listens on more than one port.
struct PortGroupRowView: View {
    let group: PortGroup
    let isExpanded: Bool
    let terminatingPIDs: Set<pid_t>
    var alias: String?
    var isFavorite = false

    private var isTerminating: Bool { terminatingPIDs.contains(group.pid) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text(group.portSummary())
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorite")
                    }
                    Spacer(minLength: 4)
                    Text("\(group.ports.count) ports")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .fixedSize()
                }
                Text(alias ?? group.processName).lineLimit(1).truncationMode(.middle)
                Text("\(group.projectName ?? "PID \(group.pid)") · PID \(group.pid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .opacity(isTerminating ? 0.6 : 1)
    }

    private var iconName: String {
        let name = group.processName.lowercased()
        if name.contains("postgres") || name.contains("redis") || name.contains("mysql") { return "cylinder" }
        if name.contains("docker") { return "shippingbox" }
        if ["node", "python", "ruby", "php", "java"].contains(where: name.contains) { return "terminal" }
        return "gearshape.2"
    }
}
