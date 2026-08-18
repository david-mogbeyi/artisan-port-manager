import SwiftUI

/// Sheet for assigning or clearing a port's alias.
struct RenamePortView: View {
    let port: ListeningPort
    let currentAlias: String?
    let onSave: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Port \(port.port)")
                .font(.headline)
            Text("Aliases are remembered per port and executable, so they survive restarts of \(port.processName).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Alias", text: $draft, prompt: Text(port.processName))
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit(save)

            HStack {
                if currentAlias != nil {
                    Button("Remove Alias", role: .destructive) {
                        onSave(nil)
                        dismiss()
                    }
                }
                Spacer(minLength: 0)
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 330)
        .onAppear {
            draft = currentAlias ?? ""
            fieldFocused = true
        }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmed.isEmpty ? nil : trimmed)
        dismiss()
    }
}
