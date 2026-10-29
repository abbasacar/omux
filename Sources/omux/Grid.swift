import SwiftUI

/// Every live session of the selected project tiled side by side. Clicking into a tile
/// selects that session; double-clicking its header shows it alone.
struct SessionGrid: View {
    @EnvironmentObject var store: Store
    let theme: Theme
    @AppStorage(Prefs.gridMode) private var gridMode = false
    @Environment(\.omuxTheme) private var themeColors

    /// Smaller than this, Claude Code's screen wraps into a mess; past it the grid scrolls.
    static let minTile = CGSize(width: 320, height: 170)

    var body: some View {
        let ids = store.gridTabIDs
        if ids.count <= 1, let id = ids.first, let term = store.terminal(for: id) {
            // One session: show it as usual, with a note instead of a lone tile.
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                    Text("Grid view shows every running session in this project. Only one is running; ⌘T starts another.")
                        .lineLimit(1)
                    Spacer()
                    Button("Exit Grid") { gridMode = false }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color(nsColor: theme.chrome))
                .overlay(alignment: .bottom) { Rectangle().fill(.primary.opacity(0.08)).frame(height: 1) }
                TerminalHost(termView: term, theme: theme, focus: store.renamingID == nil)
            }
        } else {
            grid(ids)
        }
    }

    private func grid(_ ids: [UUID]) -> some View {
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
    }

    @ViewBuilder
    private func tile(_ id: UUID) -> some View {
        if let tab = store.tab(id), let term = store.terminal(for: id) {
            let rt = store.runtime[id] ?? TabRuntime()
            let selected = store.selectedTabID == id
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    StatusDot(runtime: rt, size: 7)
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
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(themeColors.statusColor(.blocked) ?? .orange)
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
                    .strokeBorder(selected ? themeColors.accent.opacity(0.8)
                                    : rt.statusState == .blocked ? (themeColors.statusColor(.blocked) ?? .orange).opacity(0.7) : .clear,
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
