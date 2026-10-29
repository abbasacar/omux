import AppKit

/// Lets a developer capture omux's own windows without screen-recording permission,
/// for reviewing the UI. Off unless `defaults write net.pf1.omux debugHooks -bool true`.
///
/// Post the distributed notification `net.pf1.omux.debug` with one of these as its object:
/// `snapshot` writes each visible window to ~/Library/Caches/net.pf1.omux/snapshots/;
/// `palette`, `broadcast`, `recent` and `instructions` open those; `close` closes any sheet.
/// `newshell` opens a plain shell session in the selected project; `closeshell` closes the
/// newest session `newshell` opened (and never any other). `size:1440x900` sets the main
/// window's content size and `quit` quits.
///
/// A second omux started for a demo (see scripts/demo-screenshot.sh) sets
/// `OMUX_DEBUG_CHANNEL` so it listens on `net.pf1.omux.debug.<channel>` and the two don't
/// answer each other's commands, and `OMUX_DEMO_USAGE` ("5h=38,Week=21") to show those
/// limits instead of reading the Claude login.
@MainActor
enum DebugHooks {
    private static var enabled: Bool { UserDefaults.standard.bool(forKey: "debugHooks") }
    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    /// Sample usage limits for a demo, or nil to read the real ones.
    static var demoUsage: [(label: String, percent: Int)]? {
        guard enabled, let spec = environment["OMUX_DEMO_USAGE"] else { return nil }
        return spec.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: "=")
            guard parts.count == 2, let percent = Int(parts[1]) else { return nil }
            return (String(parts[0]), percent)
        }
    }

    static func install() {
        guard enabled else { return }
        let channel = environment["OMUX_DEBUG_CHANNEL"].map { "net.pf1.omux.debug.\($0)" } ?? "net.pf1.omux.debug"
        DistributedNotificationCenter.default().addObserver(forName: .init(channel), object: nil, queue: .main) { note in
            let command = note.object as? String ?? ""
            MainActor.assumeIsolated { run(command) }
        }
    }

    /// Sessions `newshell` opened, newest last; `closeshell` only closes these.
    private static var opened: [UUID] = []

    private static func run(_ command: String) {
        let store = Store.shared
        if command.hasPrefix("size:") {
            let parts = command.dropFirst(5).split(separator: "x").compactMap { Double($0) }
            if parts.count == 2, let window = store.mainWindow {
                window.setContentSize(NSSize(width: parts[0], height: parts[1]))
                window.center()
            }
            return
        }
        switch command {
        case "quit": NSApp.terminate(nil)
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

    /// Draws each visible window's content, title bar area included, into a PNG. Renders the
    /// layer tree rather than asking views to draw, so layer backgrounds (the terminal's) show.
    private static func snapshot() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("net.pf1.omux/snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let windows = NSApp.windows.filter { $0.isVisible && $0.contentView != nil && $0.frame.width > 100 }
        for (index, window) in windows.enumerated() {
            guard let view = window.contentView, let png = render(view, scale: window.backingScaleFactor) else { continue }
            let name = index == 0 ? "window.png" : "window-\(index).png"
            try? png.write(to: dir.appendingPathComponent(name), options: .atomic)
        }
    }

    private static func render(_ view: NSView, scale: CGFloat) -> Data? {
        let size = view.bounds.size
        let pixels = (width: Int(size.width * scale), height: Int(size.height * scale))
        func bitmap() -> CGContext? {
            CGContext(data: nil, width: pixels.width, height: pixels.height, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }
        guard let layer = view.layer, let capture = bitmap(), let final = bitmap() else { return nil }
        capture.scaleBy(x: scale, y: scale)
        if layer.isGeometryFlipped || view.isFlipped {
            capture.translateBy(x: 0, y: size.height)
            capture.scaleBy(x: 1, y: -1)
        }
        layer.render(in: capture)
        guard let window = capture.makeImage() else { return nil }
        // The terminal clears its background to show the layer behind it, which a capture
        // doesn't include; lay the capture over the theme's background, as on screen.
        let rect = CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height)
        final.setFillColor(Theme.current.background.cgColor)
        final.fill(rect)
        final.draw(window, in: rect)
        guard let image = final.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
