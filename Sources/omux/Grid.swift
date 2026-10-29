import SwiftUI

/// Every live session of the selected project tiled side by side. Clicking into a tile
/// selects that session; double-clicking its header shows it alone.
struct SessionGrid: View {
    @EnvironmentObject var store: Store
    let theme: Theme
    @AppStorage(Prefs.gridMode) private var gridMode = false

    var body: some View {
        let ids = store.gridTabIDs
        GeometryReader { geo in
            let (columns, rows) = Self.layout(count: ids.count, in: geo.size)
            VStack(spacing: 1) {
                ForEach(0 ..< rows, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0 ..< columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < ids.count {
                                tile(ids[index])
                            } else if index < rows * columns {
                                Color(nsColor: theme.background)
                            }
                        }
                    }
                }
            }
            .background(Color.primary.opacity(0.12))
        }
    }

    @ViewBuilder
    private func tile(_ id: UUID) -> some View {
        if let tab = store.tab(id), let term = store.terminal(for: id) {
            let rt = store.runtime[id] ?? TabRuntime()
            let selected = store.selectedTabID == id
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(rt.statusColor ?? tab.color.color ?? Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text(tab.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? .primary : .secondary)
                        .lineLimit(1)
                    if let line = rt.statusLine(showFolder: false) {
                        Text(line).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if rt.awaitsPermission {
                        PermissionButtons(tabID: id).controlSize(.mini)
                    } else if rt.needsAttention {
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    Button {
                        store.selectedTabID = id
                        gridMode = false
                    } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Show this session alone (double-click the header)")
                }
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Color(nsColor: theme.chrome))
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { store.selectedTabID = id; gridMode = false }
                .onTapGesture { store.selectedTabID = id; term.window?.makeFirstResponder(term) }
                TerminalHost(termView: term, theme: theme, focus: selected)
            }
            .overlay {
                Rectangle()
                    .strokeBorder(selected ? Color.accentColor.opacity(0.8) : rt.statusState == .blocked ? .orange.opacity(0.7) : .clear,
                                  lineWidth: selected ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Picks the column count whose tiles come closest to a terminal-friendly shape.
    static func layout(count: Int, in size: CGSize) -> (columns: Int, rows: Int) {
        guard count > 1 else { return (1, 1) }
        var best = (columns: 1, rows: count)
        var bestScore = Double.infinity
        for columns in 1 ... count {
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            let aspect = (size.width / CGFloat(columns)) / max(size.height / CGFloat(rows), 1)
            // Terminals read best around 1.6:1; empty cells cost a little.
            let score = abs(log(Double(aspect) / 1.6)) + Double(columns * rows - count) * 0.15
            if score < bestScore { bestScore = score; best = (columns, rows) }
        }
        return best
    }
}
