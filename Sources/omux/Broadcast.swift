import SwiftUI

/// Sends one prompt to several running sessions at once.
struct BroadcastSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var targets: Set<UUID> = []
    @State private var submit = true
    @FocusState private var focused: Bool

    var body: some View {
        let live = store.liveTabs
        VStack(alignment: .leading, spacing: 12) {
            Text("Broadcast to sessions").font(.headline)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .focused($focused)
                .frame(height: 110)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            if live.isEmpty {
                Text("No sessions are running.").foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("\(targets.count) of \(live.count) selected").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("All") { targets = Set(live.map(\.tab.id)) }
                    Button("This project") {
                        targets = Set(live.filter { $0.group.id == store.selectedGroup?.id }.map(\.tab.id))
                    }
                    Button("None") { targets = [] }
                }
                .controlSize(.small)
                List(live, id: \.tab.id) { entry in
                    Toggle(isOn: Binding(
                        get: { targets.contains(entry.tab.id) },
                        set: { if $0 { targets.insert(entry.tab.id) } else { targets.remove(entry.tab.id) } }
                    )) {
                        HStack {
                            Circle()
                                .fill(store.runtime[entry.tab.id]?.statusColor ?? Color.secondary.opacity(0.35))
                                .frame(width: 7, height: 7)
                            Text(entry.tab.name)
                            Text(entry.group.name).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 170)
            }
            HStack {
                Toggle("Press Return after sending", isOn: $submit)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Send to \(targets.count)") { send() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(targets.isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 520)
        .onAppear {
            // Start with the selected project's running sessions.
            targets = Set(live.filter { $0.group.id == store.selectedGroup?.id }.map(\.tab.id))
            focused = true
        }
    }

    private func send() {
        let message = text.trimmingCharacters(in: .newlines)
        for id in targets { store.sendText(message, to: id, submit: submit) }
        dismiss()
    }
}
