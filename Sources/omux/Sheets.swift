import AppKit
import SwiftUI

/// ⌘K: jump to a session or run a command. Type to filter, ↑/↓ to move, Return to pick.
struct QuickSwitcher: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selection = 0
    @State private var keyMonitor: Any?
    @Environment(\.omuxTheme) private var theme
    @FocusState private var focused: Bool

    private struct Item: Identifiable {
        let id: String
        let title: String
        var detail: String?
        var shortcut: String?
        var icon: String?
        var dot: Color?
        let run: () -> Void
    }

    private var sessions: [Item] {
        store.allTabs.map { entry in
            let rt = store.runtime[entry.tab.id]
            return Item(id: entry.tab.id.uuidString, title: entry.tab.name,
                        detail: [entry.group.name, rt?.statusLine()].compactMap { $0 }.joined(separator: " · "),
                        dot: theme.statusColor(rt?.statusState) ?? Color.secondary.opacity(0.4)) {
                store.selectedTabID = entry.tab.id
            }
        }
    }

    private var commands: [Item] {
        let id = store.selectedTabID
        let toggle = { (key: String) in UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key) }
        return [
            Item(id: "new", title: "New Session", shortcut: "⌘T", icon: "plus") { store.newTab() },
            Item(id: "shell", title: "New Shell", shortcut: "⇧⌘T", icon: "terminal") { store.newTab(command: "") },
            Item(id: "worktree", title: "New Session in Worktree…", shortcut: "⌥⌘T", icon: "arrow.triangle.branch") {
                if let g = store.selectedGroup?.id { store.newWorktreeGroupID = g }
            },
            Item(id: "project", title: "New Project", shortcut: "⇧⌘N", icon: "folder.badge.plus") { store.newGroup() },
            Item(id: "open", title: "Open Folder…", shortcut: "⌘O", icon: "folder") { store.openFolderPanel() },
            Item(id: "recent", title: "Open Recent Claude Session…", shortcut: "⇧⌘O", icon: "clock.arrow.circlepath") {
                store.showRecentSessions = true
            },
            Item(id: "grid", title: "Toggle Grid View", shortcut: "⇧⌘G", icon: "square.grid.2x2") { toggle(Prefs.gridMode) },
            Item(id: "broadcast", title: "Broadcast to Sessions…", shortcut: "⇧⌘B", icon: "dot.radiowaves.left.and.right") {
                store.showBroadcast = true
            },
            Item(id: "instructions", title: "Instructions & Skills…", shortcut: "⇧⌘I", icon: "text.book.closed") {
                store.openInstructions()
            },
            Item(id: "attention", title: "Next Session Needing You", shortcut: "⌘J", icon: "bell") { store.selectNextNeedingYou() },
            Item(id: "panel", title: "Toggle Right Panel", shortcut: "⌥⌘F", icon: "sidebar.trailing") { toggle(Prefs.showFiles) },
            Item(id: "files", title: "Show Files", shortcut: "⌥⌘1", icon: "doc") { store.showPanel(.files) },
            Item(id: "changes", title: "Show Changes", shortcut: "⌥⌘2", icon: "plusminus") { store.showPanel(.changes) },
            Item(id: "browser", title: "Show Browser", shortcut: "⌥⌘3", icon: "globe") { store.showPanel(.browser) },
            Item(id: "continue", title: "Continue Claude Conversation", shortcut: "⇧⌘↩", icon: "play") {
                if let id { store.start(id) }
            },
            Item(id: "restart", title: "Restart Session", shortcut: "⇧⌘R", icon: "arrow.clockwise") { if let id { store.restart(id) } },
            Item(id: "interrupt", title: "Interrupt (Ctrl-C)", shortcut: "⇧⌘.", icon: "stop") { if let id { store.stop(id) } },
            Item(id: "edit", title: "Edit Session…", shortcut: "⌘I", icon: "slider.horizontal.3") { store.editingTabID = id },
            Item(id: "close", title: "Close Session", shortcut: "⌘W", icon: "xmark") { if let id { store.requestClose(id) } },
            Item(id: "bigger", title: "Bigger Font", shortcut: "⌘=", icon: "textformat.size.larger") { store.zoomFont(1) },
            Item(id: "smaller", title: "Smaller Font", shortcut: "⌘−", icon: "textformat.size.smaller") { store.zoomFont(-1) },
        ] + Theme.allCases.map { theme in
            Item(id: "theme-\(theme.rawValue)", title: "Theme: \(theme.label)", icon: "paintpalette") {
                UserDefaults.standard.set(theme.rawValue, forKey: Prefs.theme)
            }
        }
    }

    /// Conversations you can reopen, labelled by Claude's title.
    private var recents: [Item] {
        store.closedRecentSessions.map { recent in
            Item(id: "recent-\(recent.id)", title: recent.displayTitle,
                 detail: "\(recent.folder) · \(recent.date.formatted(.relative(presentation: .named)))",
                 icon: "clock.arrow.circlepath") {
                store.openClaudeSession(recent)
            }
        }
    }

    /// Sessions first, then recent conversations; commands join once you type, or
    /// alone after a leading ">".
    private var items: [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(">") {
            let q = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            return commands.filter { q.isEmpty || Self.fuzzy($0.title, q) }
        }
        if trimmed.isEmpty { return sessions + recents.prefix(8) }
        let recentMatches = store.closedRecentSessions.filter {
            "\($0.title ?? "") \($0.prompt) \($0.folder)".localizedCaseInsensitiveContains(trimmed)
        }.map(\.id)
        return sessions.filter { Self.fuzzy("\($0.title) \($0.detail ?? "")", trimmed) }
            + recents.filter { item in recentMatches.contains { "recent-\($0)" == item.id } }.prefix(20)
            + commands.filter { Self.fuzzy($0.title, trimmed) }
    }

    /// Every query character appears in order, so "nws" finds "New Session".
    static func fuzzy(_ text: String, _ query: String) -> Bool {
        if text.localizedCaseInsensitiveContains(query) { return true }
        var rest = Substring(query.lowercased().filter { !$0.isWhitespace })
        for ch in text.lowercased() where ch == rest.first {
            rest = rest.dropFirst()
            if rest.isEmpty { return true }
        }
        return rest.isEmpty
    }

    var body: some View {
        let list = items
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Jump to a session or old conversation, > for commands…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($focused)
                    .onSubmit { pick(list) }
            }
            .padding(12)
            Divider()
            if list.isEmpty {
                Text("No matches").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                                row(item, selected: index == selection)
                                    .id(index)
                                    .onHover { if $0 { selection = index } }
                                    .onTapGesture { selection = index; pick(list) }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: selection) { _, value in proxy.scrollTo(value) }
                }
            }
        }
        .frame(width: 520, height: 400)
        .onAppear {
            focused = true
            // ↑/↓ move the highlight. The search field's editor would take them as cursor
            // moves before SwiftUI saw them, so catch them on the way in.
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                switch event.keyCode {
                case 125: move(1, count: items.count); return nil
                case 126: move(-1, count: items.count); return nil
                default: return event
                }
            }
        }
        .onDisappear {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
        }
        .onChange(of: query) { _, _ in selection = 0 }
        .onExitCommand { dismiss() }
    }

    private func row(_ item: Item, selected: Bool) -> some View {
        HStack(spacing: 8) {
            if let dot = item.dot {
                Circle().fill(dot).frame(width: 8, height: 8).frame(width: 16)
            } else if let icon = item.icon {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 16)
            }
            Text(item.title).lineLimit(1)
            if let detail = item.detail {
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let shortcut = item.shortcut {
                Text(shortcut).font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(selected ? theme.accent.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private func move(_ step: Int, count: Int) {
        guard count > 0 else { return }
        selection = (selection + step + count) % count
    }

    private func pick(_ list: [Item]) {
        guard list.indices.contains(selection) else { return }
        // Runs once the sheet has closed, so commands that open another sheet can.
        store.pendingPaletteAction = list[selection].run
        dismiss()
    }
}

private func chooseDirectory(current: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    if !current.isEmpty {
        panel.directoryURL = URL(fileURLWithPath: (current as NSString).expandingTildeInPath)
    }
    return panel.runModal() == .OK ? panel.url?.path : nil
}

struct TabEditSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let tabID: UUID

    private enum CommandMode: String, CaseIterable, Identifiable {
        case inherit = "Project default", shell = "Plain shell", custom = "Custom"
        var id: String { rawValue }
    }

    @State private var name = ""
    @State private var directory = ""
    @State private var mode: CommandMode = .inherit
    @State private var customCommand = ""
    @State private var sessionID = UUID()

    var body: some View {
        let group = store.group(containing: tabID)
        Form {
            TextField("Name", text: $name)
            HStack {
                TextField("Folder", text: $directory, prompt: Text(group?.directory ?? "~"))
                Button("Choose…") { if let dir = chooseDirectory(current: directory) { directory = dir } }
            }
            Picker("Command", selection: $mode) {
                ForEach(CommandMode.allCases) { Text($0.rawValue).tag($0) }
            }
            if mode == .custom {
                TextField("Command", text: $customCommand, prompt: Text("claude"))
            } else if mode == .inherit {
                Text(group?.command?.isEmpty == false ? group!.command! : "plain shell")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent("Claude session") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionID.uuidString.lowercased())
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                    Button("Start a fresh conversation on next restart") {
                        sessionID = UUID()
                    }
                    .controlSize(.small)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            guard let tab = store.tab(tabID) else { return }
            name = tab.name
            directory = tab.directory ?? ""
            switch tab.command {
            case nil: mode = .inherit
            case "": mode = .shell
            case let cmd?: mode = .custom; customCommand = cmd
            }
            sessionID = tab.claudeSessionID
        }
    }

    private func save() {
        store.updateTab(tabID) { tab in
            tab.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? tab.name : name
            tab.directory = directory.isEmpty ? nil : directory
            switch mode {
            case .inherit: tab.command = nil
            case .shell: tab.command = ""
            case .custom: tab.command = customCommand.isEmpty ? nil : customCommand
            }
            tab.claudeSessionID = sessionID
        }
        dismiss()
    }
}

struct GroupEditSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID

    @State private var name = ""
    @State private var directory = ""
    @State private var command = ""
    @State private var useWorktrees = false

    var body: some View {
        Form {
            TextField("Name", text: $name)
            HStack {
                TextField("Folder", text: $directory, prompt: Text("~"))
                Button("Choose…") { if let dir = chooseDirectory(current: directory) { directory = dir } }
            }
            TextField("Command for new sessions", text: $command, prompt: Text("leave empty for a plain shell"))
            Text("Applies when a session starts. Existing sessions keep running.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Give new sessions their own Git worktree", isOn: $useWorktrees)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            guard let group = store.groups.first(where: { $0.id == groupID }) else { return }
            name = group.name
            directory = group.directory ?? ""
            command = group.command ?? ""
            useWorktrees = group.useWorktrees
        }
    }

    private func save() {
        store.updateGroup(groupID) { group in
            group.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? group.name : name
            group.directory = directory.isEmpty ? nil : directory
            group.command = command
            group.useWorktrees = useWorktrees
        }
        dismiss()
    }
}

struct RecentSessionsSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    private var sessions: [RecentSession] { store.recentSessions }
    @State private var query = ""
    @State private var byFolder = false
    @FocusState private var focused: Bool

    private var matches: [RecentSession] {
        sessions.filter { query.isEmpty || "\($0.title ?? "") \($0.prompt) \($0.folder)".localizedCaseInsensitiveContains(query) }
    }

    /// Folders ordered by their most recent session; sessions stay newest-first within each.
    private var folders: [(folder: String, sessions: [RecentSession])] {
        var order: [String] = []
        var grouped: [String: [RecentSession]] = [:]
        for session in matches {
            if grouped[session.folder] == nil { order.append(session.folder) }
            grouped[session.folder, default: []].append(session)
        }
        return order.map { ($0, grouped[$0]!) }
    }

    private var openIDs: Set<UUID> { Set(store.allTabs.map(\.tab.claudeSessionID)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField("Search recent Claude sessions…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($focused)
                    .onSubmit { if let first = matches.first { pick(first) } }
                Picker("", selection: $byFolder) {
                    Text("Recent").tag(false)
                    Text("By folder").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .padding(12)
            Divider()
            if !store.recentLoaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if matches.isEmpty {
                Text(sessions.isEmpty ? "No Claude sessions found in ~/.claude/projects" : "No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if byFolder {
                        ForEach(folders, id: \.folder) { entry in
                            Section(entry.folder) {
                                ForEach(entry.sessions) { row($0, showFolder: false) }
                            }
                        }
                    } else {
                        ForEach(matches) { row($0, showFolder: true) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 560, height: 440)
        .onExitCommand { dismiss() }
        .task {
            focused = true
            store.refreshRecentSessions()
        }
    }

    private func row(_ session: RecentSession, showFolder: Bool) -> some View {
        Button { pick(session) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.displayTitle).lineLimit(1)
                    Spacer()
                    if openIDs.contains(session.id) {
                        Text("open").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if session.title != nil {
                    Text(session.prompt).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack {
                    if showFolder { Text(session.folder) }
                    Spacer()
                    Text(session.date, format: .relative(presentation: .named))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ session: RecentSession) {
        store.openClaudeSession(session)
        dismiss()
    }
}
