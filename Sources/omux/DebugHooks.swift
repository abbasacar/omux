import AppKit

/// Lets a developer capture omux's own windows without screen-recording permission,
/// for reviewing the UI. Off unless `defaults write net.pf1.omux debugHooks -bool true`.
///
/// Post the distributed notification `net.pf1.omux.debug` with one of these as its object:
/// `snapshot` writes each visible window to ~/Library/Caches/net.pf1.omux/snapshots/;
/// `palette`, `broadcast`, `recent` and `instructions` open those; `close` closes any sheet.
/// `newshell` opens a plain shell session in the selected project; `closeshell` closes the
/// newest session `newshell` opened (and never any other).
@MainActor
enum DebugHooks {
    static func install() {
        guard UserDefaults.standard.bool(forKey: "debugHooks") else { return }
        DistributedNotificationCenter.default().addObserver(forName: .init("net.pf1.omux.debug"), object: nil, queue: .main) { note in
            let command = note.object as? String ?? ""
            MainActor.assumeIsolated { run(command) }
        }
    }

    /// Sessions `newshell` opened, newest last; `closeshell` only closes these.
    private static var opened: [UUID] = []

    private static func run(_ command: String) {
        let store = Store.shared
        switch command {
        case "newshell":
            store.newTab(command: "")
            if let id = store.selectedTabID { opened.append(id) }
        case "closeshell":
            if let id = opened.popLast() { store.closeTab(id) }
        case "snapshot": snapshot()
        case "palette": store.showQuickSwitcher = true
        case "broadcast": store.showBroadcast = true
        case "recent": store.showRecentSessions = true
        case "instructions": store.openInstructions()
        case "close":
            store.showQuickSwitcher = false
            store.showBroadcast = false
            store.showRecentSessions = false
        default: break
        }
    }

    /// Draws each visible window's content, title bar area included, into a PNG.
    private static func snapshot() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("net.pf1.omux/snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let windows = NSApp.windows.filter { $0.isVisible && $0.contentView != nil && $0.frame.width > 100 }
        for (index, window) in windows.enumerated() {
            guard let view = window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { continue }
            let name = index == 0 ? "window.png" : "window-\(index).png"
            try? png.write(to: dir.appendingPathComponent(name), options: .atomic)
        }
    }
}
