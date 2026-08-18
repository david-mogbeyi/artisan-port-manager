import SwiftUI

struct PortRowView: View {
    let port: ListeningPort
    let isTerminating: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text(String(port.port)).font(.headline.monospacedDigit())
                    Spacer()
                }
                Text(port.processName).lineLimit(1)
                Text("\(port.projectName ?? port.addressFamily.rawValue) · PID \(port.pid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .opacity(isTerminating ? 0.6 : 1)
    }

    private var iconName: String {
        let name = port.processName.lowercased()
        if name.contains("postgres") || name.contains("redis") || name.contains("mysql") { return "cylinder" }
        if name.contains("docker") { return "shippingbox" }
        if ["node", "python", "ruby", "php", "java"].contains(where: name.contains) { return "terminal" }
        return "gearshape.2"
    }
}
