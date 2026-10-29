import AppKit
import SwiftUI

@main
struct OmuxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = Store.shared
    @AppStorage(Prefs.showMenuBar) private var showMenuBar = true

    var body: some Scene {
        Window("omux", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 420)
        }
        .defaultSize(width: 1240, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands { AppCommands(store: store) }

        Settings { SettingsView() }

        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarContent().environmentObject(store)
        } label: {
            MenuBarLabel().environmentObject(store)
        }
    }
}

/// The menu bar icon: a terminal glyph, with a count while sessions wait on you.
struct MenuBarLabel: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let waiting = store.attentionCount
        if waiting > 0 {
            Label("\(waiting)", systemImage: "bell.badge.fill").labelStyle(.titleAndIcon)
        } else {
            Image(systemName: store.runtime.values.contains { $0.statusState == .working } ? "terminal.fill" : "terminal")
        }
    }
}

/// Every session with its status; picking one brings omux forward on it.
struct MenuBarContent: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ForEach(store.groups) { group in
            Section(group.name) {
                ForEach(group.tabs) { tab in
                    let rt = store.runtime[tab.id] ?? TabRuntime()
                    Button {
                        store.reveal(tab.id)
                    } label: {
                        Text("\(Self.symbol(rt)) \(tab.name)  —  \(rt.statusLine(showFolder: false) ?? "Idle")")
                    }
                }
            }
        }
        Divider()
        Button("Next Session Needing You") { store.selectNextNeedingYou() }
            .disabled(store.attentionCount == 0)
        Button("Open omux") { AppDelegate.openWindow?(id: "main"); NSApp.activate() }
        Divider()
        Button("Quit omux") { NSApp.terminate(nil) }
    }

    private static func symbol(_ rt: TabRuntime) -> String {
        switch rt.statusState {
        case .blocked: return "🟠"
        case .working: return "🔵"
        case .done: return "🟢"
        case .error: return "🔴"
        default: return rt.needsAttention ? "🔔" : rt.exited ? "⚪️" : "⚫️"
        }
    }
}

enum Prefs {
    static let confirmQuit = "confirmQuit"
    static let showFolderPath = "showFolderPath"
    static let usageInterval = "usageInterval"
    static let theme = "theme"
    static let autoResume = "autoResume"
    static let showFiles = "showFiles"
    static let filesByDate = "filesByDate"
    static let filesBrowserCollapsed = "filesBrowserCollapsed"
    static let previewWrapLines = "previewWrapLines"
    static let panelTab = "panelTab"
    static let fontFamily = "fontFamily"
    static let fontSize = "fontSize"
    static let notifyNeedsYou = "notifyNeedsYou"
    static let notifyDone = "notifyDone"
    static let notifyPrograms = "notifyPrograms"
    static let gridMode = "gridMode"
    static let showMenuBar = "showMenuBar"
    static let recentCollapsed = "recentCollapsed"
}

struct SettingsView: View {
    @AppStorage(Prefs.confirmQuit) private var confirmQuit = true
    @AppStorage(Prefs.showFolderPath) private var showFolderPath = true
    @AppStorage(Prefs.usageInterval) private var usageInterval = 300.0
    @AppStorage(Prefs.theme) private var theme = Theme.dark.rawValue
    @AppStorage(Prefs.fontFamily) private var fontFamily = ""
    @AppStorage(Prefs.fontSize) private var fontSize = 13.0
    @AppStorage(Prefs.autoResume) private var autoResume = false
    @AppStorage(Prefs.previewWrapLines) private var wrapLines = true
    @AppStorage(Prefs.notifyNeedsYou) private var notifyNeedsYou = true
    @AppStorage(Prefs.notifyDone) private var notifyDone = false
    @AppStorage(Prefs.notifyPrograms) private var notifyPrograms = true
    @AppStorage(Prefs.showMenuBar) private var showMenuBar = true

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Picker("Font", selection: $fontFamily) {
                    Text("System Mono").tag("")
                    ForEach(Fonts.monospaceFamilies, id: \.self) { Text($0).tag($0) }
                }
                Stepper("Font size: \(Int(fontSize)) pt", value: $fontSize, in: 9 ... 28)
                Text("⌘= and ⌘− change it from anywhere, ⌘0 resets it. With a light theme, also pick a light theme in Claude Code (/theme) so its colors stay readable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Sidebar") {
                Toggle("Show folder path under session name", isOn: $showFolderPath)
                Picker("Check Claude limits every", selection: $usageInterval) {
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("30 minutes").tag(1800.0)
                    Text("Hour").tag(3600.0)
                }
            }
            Section("Claude") {
                LabeledContent("Instructions, skills and agents") {
                    Button("Open…") {
                        AppDelegate.openWindow?(id: "main")
                        Store.shared.showInstructions = true
                    }
                }
                Text("CLAUDE.md, omux-only instructions, skills and custom agents, for every project or the current one. Also ⇧⌘I.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Menu Bar") {
                Toggle("Show session status in the menu bar", isOn: $showMenuBar)
            }
            Section("Files Panel") {
                Toggle("Wrap long lines in file preview", isOn: $wrapLines)
            }
            Section("Sessions") {
                Toggle("Auto-resume Claude sessions at launch", isOn: $autoResume)
                Text("Off: restored sessions stay stopped until you press ▶. Clicking one only opens its shell.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Confirm before quitting while sessions are running", isOn: $confirmQuit)
                Text("Quitting always stops every session. Claude conversations resume on the next launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Notifications") {
                Toggle("When a session needs you", isOn: $notifyNeedsYou)
                Toggle("When a session finishes", isOn: $notifyDone)
                Toggle("When a program in a session sends one", isOn: $notifyPrograms)
                Text("Only for sessions you aren't looking at. Programs send them with OSC 9 or OSC 777: set Claude Code's notification channel to ghostty (/config) to get its plugins' notifications too.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Prefs.theme) private var themeName = Theme.dark.rawValue
    @AppStorage(Prefs.fontFamily) private var fontFamily = ""
    @AppStorage(Prefs.fontSize) private var fontSize = 13.0
    @AppStorage(Prefs.showFiles) private var showFiles = false
    @AppStorage(Prefs.gridMode) private var gridMode = false

    private var theme: Theme { Theme(rawValue: themeName) ?? .dark }

    /// Changes follow the selected session and its folder.
    private var changesKey: String {
        let tab = store.selectedTab
        return "\(tab?.id.uuidString ?? "")|\(tab?.directory ?? "")|\(tab?.worktree?.branch ?? "")"
    }

    /// Folder the file panel shows: the selected session's folder, else its project's.
    private var projectRoot: URL {
        let tab = store.selectedTab
        let group = store.selectedGroup
        let path = tab?.directory ?? group?.directory ?? NSHomeDirectory()
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(theme: theme)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            HSplitView {
                VStack(spacing: 0) {
                    SessionHeader(theme: theme, showFiles: $showFiles, gridMode: $gridMode)
                    if gridMode, store.selectedTabID != nil {
                        SessionGrid(theme: theme)
                    } else if let id = store.selectedTabID, let term = store.terminal(for: id) {
                        TerminalHost(termView: term, theme: theme, focus: store.renamingID == nil)
                    } else {
                        ContentUnavailableView("No session", systemImage: "terminal", description: Text("Press ⌘T to start one."))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(nsColor: theme.background))
                    }
                }
                .frame(minWidth: 360)
                if showFiles {
                    RightPanel(root: projectRoot, theme: theme)
                        .frame(minWidth: 260, idealWidth: 380, maxWidth: 900)
                }
            }
        }
        // Hiding the toolbar itself also hides the window buttons on some macOS versions.
        .toolbarBackground(.hidden, for: .windowToolbar)
        .preferredColorScheme(theme.colorScheme)
        .environment(\.omuxTheme, theme)
        .tint(theme.accent)
        .background(Color(nsColor: theme.chrome))
        .onChange(of: themeName) { _, _ in store.applyAppearance() }
        .onChange(of: fontFamily) { _, _ in store.applyAppearance() }
        .onChange(of: fontSize) { _, _ in store.applyAppearance() }
        .onChange(of: store.previewRequest) { _, path in if path != nil { store.showPanel(.files) } }
        .onChange(of: changesKey, initial: true) { _, _ in
            let tab = store.selectedTab
            Changes.shared.track(tabID: tab?.id, dir: tab.flatMap(store.directory(of:)), worktree: tab?.worktree)
        }
        .sheet(item: $store.newWorktreeGroupID) { WorktreeSheet(groupID: $0).environmentObject(store) }
        .sheet(isPresented: $store.showQuickSwitcher, onDismiss: { store.runPendingPaletteAction() }) {
            QuickSwitcher().environmentObject(store)
        }
        .sheet(isPresented: $store.showRecentSessions) { RecentSessionsSheet().environmentObject(store) }
        .sheet(isPresented: $store.showBroadcast) { BroadcastSheet().environmentObject(store) }
        .sheet(isPresented: $store.showInstructions) { InstructionsSheet().environmentObject(store) }
        .sheet(item: $store.editingTabID) { TabEditSheet(tabID: $0).environmentObject(store) }
        .sheet(item: $store.editingGroupID) { GroupEditSheet(groupID: $0).environmentObject(store) }
        .onAppear { AppDelegate.openWindow = openWindow }
        .background(WindowReader { store.mainWindow = $0 })
    }
}

/// Slim strip above the terminal: name, live status, folder and stop/start.
struct SessionHeader: View {
    @EnvironmentObject var store: Store
    let theme: Theme
    @Binding var showFiles: Bool
    @Binding var gridMode: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let tab = store.selectedTab {
                let rt = store.runtime[tab.id] ?? TabRuntime()
                StatusDot(runtime: rt)
                Text(tab.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .layoutPriority(1)
                if let line = rt.statusLine(showFolder: false) {
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if rt.awaitsPermission {
                    PermissionButtons(tabID: tab.id).controlSize(.mini).fixedSize().layoutPriority(2)
                }
                Spacer(minLength: 6)
                // The chips and folder give way first when the header gets narrow.
                ViewThatFits(in: .horizontal) {
                    details(tab, rt, folder: true)
                    details(tab, rt, folder: false)
                    AgentPill(tabID: tab.id)
                    Color.clear.frame(width: 0)
                }
                if rt.busy {
                    Button { store.stop(tab.id) } label: { Image(systemName: "stop.fill") }
                        .buttonStyle(IconButtonStyle())
                        .help("Interrupt (Ctrl-C)")
                        .accessibilityLabel("Interrupt")
                } else {
                    Button { store.start(tab.id) } label: { Image(systemName: "play.fill") }
                        .buttonStyle(IconButtonStyle())
                        .help("Continue this Claude conversation")
                        .accessibilityLabel("Continue Claude conversation")
                }
            } else {
                Spacer()
            }
            HStack(spacing: 0) {
                Button { store.showBroadcast = true } label: { Image(systemName: "dot.radiowaves.left.and.right") }
                    .help("Broadcast a prompt to several sessions (⇧⌘B)")
                    .accessibilityLabel("Broadcast to sessions")
                    .disabled(store.isSheetOpen)
                Button { gridMode.toggle() } label: { Image(systemName: gridMode ? "square.grid.2x2.fill" : "square.grid.2x2") }
                    .foregroundStyle(gridMode ? .primary : .secondary)
                    .help("Grid: every running session in this project side by side (⇧⌘G)")
                    .accessibilityLabel(gridMode ? "Show one session" : "Grid view")
                Button { showFiles.toggle() } label: { Image(systemName: "sidebar.trailing") }
                    .foregroundStyle(showFiles ? .primary : .secondary)
                    .help("Files panel (⌥⌘F)")
                    .accessibilityLabel(showFiles ? "Hide right panel" : "Show right panel")
            }
            .buttonStyle(IconButtonStyle())
            .fixedSize()
            .layoutPriority(3)
        }
        .foregroundStyle(.secondary)
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color(nsColor: theme.chrome))
        .overlay(alignment: .bottom) { Rectangle().fill(.primary.opacity(0.08)).frame(height: 1) }
    }

    @ViewBuilder
    private func details(_ tab: TabItem, _ rt: TabRuntime, folder: Bool) -> some View {
        HStack(spacing: 8) {
            AgentPill(tabID: tab.id)
            if let worktree = tab.worktree {
                PullRequestChip(tabID: tab.id)
                if folder { BranchChip(tabID: tab.id, worktree: worktree) }
            } else if folder, let cwd = rt.cwd {
                Text((cwd as NSString).abbreviatingWithTildeInPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: 260)
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

/// Finds the window a view is in, so commands can tell the main window from Settings.
struct WindowReader: NSViewRepresentable {
    let found: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { found(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

struct AppCommands: Commands {
    @ObservedObject var store: Store

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Session") { store.newTab() }.keyboardShortcut("t")
            Button("New Shell") { store.newTab(command: "") }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("New Session in Worktree…") {
                if let id = store.selectedGroup?.id ?? store.groups.first?.id { store.newWorktreeGroupID = id }
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            .disabled(store.isSheetOpen)
            Button("New Project") { store.newGroup() }.keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Open Folder…") { store.openFolderPanel() }.keyboardShortcut("o")
            Button("Open Recent Claude Session…") { store.showRecentSessions = true }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(store.isSheetOpen)
        }
        CommandGroup(replacing: .saveItem) {
            // ⌘W closes the session only in the main window; elsewhere (Settings) it
            // closes that window, as it would in any app.
            Button("Close Session") {
                if let window = NSApp.keyWindow, window !== store.mainWindow {
                    window.performClose(nil)
                } else if let id = store.selectedTabID {
                    store.requestClose(id)
                }
            }
            .keyboardShortcut("w")
            Button("Close Window") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: [.command, .shift])
        }
        CommandGroup(after: .sidebar) {
            Button("Grid View") {
                UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: Prefs.gridMode), forKey: Prefs.gridMode)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            Divider()
            Button("Bigger Font") { store.zoomFont(1) }.keyboardShortcut("=")
            Button("Smaller Font") { store.zoomFont(-1) }.keyboardShortcut("-")
            Button("Actual Font Size") { store.zoomFont(0) }.keyboardShortcut("0")
            Divider()
            Button("Files Panel") {
                UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: Prefs.showFiles), forKey: Prefs.showFiles)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            Button("Files") { store.showPanel(.files) }.keyboardShortcut("1", modifiers: [.command, .option])
            Button("Changes") { store.showPanel(.changes) }.keyboardShortcut("2", modifiers: [.command, .option])
            Button("Browser") { store.showPanel(.browser) }.keyboardShortcut("3", modifiers: [.command, .option])
        }
        CommandMenu("Session") {
            // No shortcut: ⌘R is left to the terminal. Rename from the sidebar's menu or ⌘I.
            Button("Rename") { store.renamingID = store.selectedTabID }
            Button("Edit Session…") { store.editingTabID = store.selectedTabID }
                .keyboardShortcut("i")
                .disabled(store.isSheetOpen)
            Button("Restart Session") { if let id = store.selectedTabID { store.restart(id) } }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Interrupt (Ctrl-C)") { if let id = store.selectedTabID { store.stop(id) } }
                .keyboardShortcut(".", modifiers: [.command, .shift])
            Button("Kill Session") { if let id = store.selectedTabID { store.kill(id) } }
            Button("Continue Claude Conversation") { if let id = store.selectedTabID { store.start(id) } }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
            Divider()
            Button("Command Palette…") { store.showQuickSwitcher = true }
                .keyboardShortcut("k")
                .disabled(store.isSheetOpen)
            Button("Next Session Needing You") { store.selectNextNeedingYou() }.keyboardShortcut("j")
            Button("Broadcast to Sessions…") { store.showBroadcast = true }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(store.isSheetOpen)
            Button("Instructions & Skills…") { store.showInstructions = true }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(store.isSheetOpen)
            Button("Next Session") { store.selectRelative(1) }.keyboardShortcut("]", modifiers: [.command, .shift])
            Button("Previous Session") { store.selectRelative(-1) }.keyboardShortcut("[", modifiers: [.command, .shift])
            Divider()
            ForEach(1 ..< 10, id: \.self) { n in
                Button("Session \(n) in Project") { store.selectIndex(n - 1) }
                    .keyboardShortcut(KeyEquivalent(Character(String(n))))
            }
        }
    }
}

/// Finder's right-click "Open in omux" on folders (declared under NSServices in Info.plist).
final class ServiceProvider: NSObject {
    @objc func openFolders(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            AppDelegate.openWindow?(id: "main")
            urls.forEach { Store.shared.openFolder($0.path) }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var openWindow: OpenWindowAction?
    private let services = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
        Notifier.shared.activate()
        DebugHooks.install()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Folders dropped on the Dock icon, opened via Finder's "Open With", or `open -a omux <dir>`.
    func application(_ application: NSApplication, open urls: [URL]) {
        Self.openWindow?(id: "main")
        urls.forEach { Store.shared.openFolder($0.path) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { Self.openWindow?(id: "main") }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let store = Store.shared
        let running = store.runningSessionCount
        let confirm = UserDefaults.standard.object(forKey: Prefs.confirmQuit) as? Bool ?? true
        if confirm, running > 0 {
            let alert = NSAlert()
            alert.messageText = "Quit omux?"
            alert.informativeText = "\(running) session\(running == 1 ? " is" : "s are") running. Claude sessions resume automatically on next launch."
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn { return .terminateCancel }
        }
        store.prepareForTermination()
        return .terminateNow
    }
}
