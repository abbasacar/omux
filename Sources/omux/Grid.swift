import SwiftUI

/// Every live session of the selected project tiled side by side. Clicking into a tile
/// selects that session; double-clicking its header shows it alone.
struct SessionGrid: View {
    @EnvironmentObject var store: Store
    let theme: Theme
    @AppStorage(Prefs.gridMode) private var gridMode = false

    /// Smaller than this, Claude Code's screen wraps into a mess; past it the grid scrolls.
    static let minTile = CGSize(width: 320, height: 170)

    var body: some View {
        let ids = store.gridTabIDs
        GeometryReader { geo in
            let (columns, rows) = Self.layout(count: ids.count, in: geo.size)
            let tileHeight = max(geo.size.height / CGFloat(rows), Self.minTile.height)
            ScrollView(.vertical) {
                VStack(spacing: 1) {
                    ForEach(0 ..< rows, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0 ..< columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < ids.count {
                                    tile(ids[index])
                                } else {
                                    Color(nsColor: theme.background)
                                }
                            }
                        }
                        .frame(height: tileHeight - (row < rows - 1 ? 1 : 0))
                    }
                }
            }
            .scrollDisabled(tileHeight * CGFloat(rows) <= geo.size.height + 1)
            .background(Color.primary.opacity(0.12))
        }
        .overlay(alignment: .bottom) {
            if ids.count == 1 {
                Text("Only one session is running in this project. Start more with ⌘T to see them side by side.")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(12)
                    .allowsHitTesting(false)
            }
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
                        PermissionButtons(tabID: id).controlSize(.mini).fixedSize()
                    } else if rt.needsAttention {
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    Button {
                        store.selectedTabID = id
                        gridMode = false
                    } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(IconButtonStyle())
                        .foregroundStyle(.secondary)
                        .help("Show this session alone (double-click the header)")
                        .accessibilityLabel("Show \(tab.name) alone")
                }
                .padding(.leading, 8)
                .padding(.trailing, 2)
                .frame(height: 26)
                .background(Color(nsColor: theme.chrome))
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { store.selectedTabID = id; gridMode = false }
                // Alongside the double-click, so a single click selects at once instead of
                // waiting to see whether a second click follows.
                .simultaneousGesture(TapGesture().onEnded {
                    store.selectedTabID = id
                    term.window?.makeFirstResponder(term)
                })
                TerminalHost(termView: term, theme: theme, focus: selected && store.renamingID == nil)
            }
            .overlay {
                Rectangle()
                    .strokeBorder(selected ? Color.accentColor.opacity(0.8) : rt.statusState == .blocked ? .orange.opacity(0.7) : .clear,
                                  lineWidth: selected ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Picks the column count whose tiles come closest to a terminal-friendly shape,
    /// never narrower than `minTile`.
    static func layout(count: Int, in size: CGSize) -> (columns: Int, rows: Int) {
        guard count > 1 else { return (1, 1) }
        let maxColumns = max(1, min(count, Int(size.width / minTile.width)))
        var best = (columns: 1, rows: count)
        var bestScore = Double.infinity
        for columns in 1 ... maxColumns {
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            let height = max(size.height / CGFloat(rows), minTile.height)
            let aspect = (size.width / CGFloat(columns)) / max(height, 1)
            // Terminals read best around 1.6:1; empty cells cost a little.
            let score = abs(log(Double(aspect) / 1.6)) + Double(columns * rows - count) * 0.15
            if score < bestScore { bestScore = score; best = (columns, rows) }
        }
        return best
    }
}
