import AppKit
import SwiftUI

/// Instructions omux adds to every Claude session it starts: global ones, then the
/// project's. They reach Claude through `--append-system-prompt`, so they apply only to
/// sessions omux launches, unlike CLAUDE.md.
enum OmuxInstructions {
    static var globalURL: URL { Persistence.directory.appendingPathComponent("instructions.md") }

    static var global: String {
        get { (try? String(contentsOf: globalURL, encoding: .utf8)) ?? "" }
        set { try? newValue.write(to: globalURL, atomically: true, encoding: .utf8) }
    }

    /// The combined text for a project's sessions, or nil when there's nothing to add.
    static func text(for group: TabGroup) -> String? {
        let parts = [global, group.instructions ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    /// The `claude` argument carrying a project's instructions. The text goes through a
    /// file the shell reads, so quotes and newlines in it need no escaping.
    static func flag(for group: TabGroup) -> String? {
        guard let text = text(for: group) else { return nil }
        let dir = Persistence.directory.appendingPathComponent("prompts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(group.id.uuidString).md")
        guard (try? text.write(to: file, atomically: true, encoding: .utf8)) != nil else { return nil }
        let quoted = "'" + file.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "--append-system-prompt \"$(cat \(quoted))\""
    }
}

/// A skill or custom agent Claude Code would load, from ~/.claude or a project's .claude.
struct ClaudeAsset: Identifiable, Hashable {
    enum Kind { case skill, agent }
    let kind: Kind
    let name: String
    /// SKILL.md for a skill, the agent's .md file for an agent.
    let file: URL
    let inProject: Bool
    /// Synced from claude.ai: Claude replaces these, so omux shows them read-only.
    let synced: Bool
    var id: String { file.path }

    /// Skills under `root/skills` (each a folder with SKILL.md, synced ones nested deeper)
    /// and agents in `root/agents`.
    static func scan(_ root: URL, inProject: Bool) -> [ClaudeAsset] {
        let fm = FileManager.default
        var result: [ClaudeAsset] = []
        let skills = root.appendingPathComponent("skills")
        if let walker = fm.enumerator(at: skills, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let url as URL in walker {
                if walker.level > 4 { walker.skipDescendants(); continue }
                guard url.lastPathComponent == "SKILL.md" else { continue }
                let folder = url.deletingLastPathComponent()
                result.append(ClaudeAsset(kind: .skill, name: folder.lastPathComponent, file: url, inProject: inProject,
                                          synced: url.path.contains("/skills/synced/")))
            }
        }
        let agents = root.appendingPathComponent("agents")
        for url in (try? fm.contentsOfDirectory(at: agents, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "md" {
            result.append(ClaudeAsset(kind: .agent, name: url.deletingPathExtension().lastPathComponent, file: url,
                                      inProject: inProject, synced: false))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Creates a skill or agent from a template and returns its file.
    static func create(_ kind: Kind, named name: String, in root: URL) throws -> URL {
        let fm = FileManager.default
        switch kind {
        case .skill:
            let folder = root.appendingPathComponent("skills/\(name)", isDirectory: true)
            let file = folder.appendingPathComponent("SKILL.md")
            guard !fm.fileExists(atPath: file.path) else { throw CocoaError(.fileWriteFileExists) }
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try """
            ---
            name: \(name)
            description: What this skill does, and when Claude should use it. Claude reads this to decide.
            ---

            # \(name)

            Step-by-step instructions Claude follows when it uses this skill.
            """.write(to: file, atomically: true, encoding: .utf8)
            return file
        case .agent:
            let folder = root.appendingPathComponent("agents", isDirectory: true)
            let file = folder.appendingPathComponent("\(name).md")
            guard !fm.fileExists(atPath: file.path) else { throw CocoaError(.fileWriteFileExists) }
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try """
            ---
            name: \(name)
            description: When Claude should hand work to this agent.
            tools: Read, Grep, Glob, Bash
            ---

            You are a specialist who… Describe the agent's role, how it works and what it reports back.
            """.write(to: file, atomically: true, encoding: .utf8)
            return file
        }
    }
}

/// One place for everything that shapes Claude's behavior in omux: CLAUDE.md files,
/// omux's own instructions, skills and custom agents, globally and for the current project.
struct InstructionsSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private enum Item: Hashable {
        case claudeGlobal, omuxGlobal, claudeProject, omuxProject
        case asset(ClaudeAsset)
    }

    @State private var selection: Item? = .claudeGlobal
    @State private var assets: [ClaudeAsset] = []
    @State private var text = ""
    @State private var saved = ""
    @State private var creating: ClaudeAsset.Kind?

    private var group: TabGroup? { store.selectedGroup }
    private var projectDir: URL? {
        group?.directory.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    }
    private static let claudeHome = URL(fileURLWithPath: NSHomeDirectory() + "/.claude")

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 230)
            Divider()
            detail.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 820, height: 560)
        .onAppear { reloadAssets(); load() }
        .onChange(of: selection) { _, _ in load() }
        .sheet(item: $creating) { kind in
            NewAssetSheet(kind: kind, hasProject: projectDir != nil) { name, inProject in
                create(kind, name: name, inProject: inProject)
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Everywhere") {
                    Label("CLAUDE.md", systemImage: "doc.text").tag(Item.claudeGlobal)
                    Label("omux instructions", systemImage: "terminal").tag(Item.omuxGlobal)
                }
                if let group {
                    Section("Project: \(group.name)") {
                        if projectDir != nil {
                            Label("CLAUDE.md", systemImage: "doc.text").tag(Item.claudeProject)
                        }
                        Label("omux instructions", systemImage: "terminal").tag(Item.omuxProject)
                    }
                }
                assetSection("Skills", kind: .skill, icon: "sparkles")
                assetSection("Agents", kind: .agent, icon: "person.crop.circle")
            }
            .listStyle(.sidebar)
            Divider()
            HStack {
                Menu {
                    Button("New Skill…") { creating = .skill }
                    Button("New Agent…") { creating = .agent }
                } label: { Image(systemName: "plus") }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Create a skill or a custom agent")
                    .accessibilityLabel("New skill or agent")
                Spacer()
                Button("Done") { saveIfNeeded(); dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func assetSection(_ title: String, kind: ClaudeAsset.Kind, icon: String) -> some View {
        let items = assets.filter { $0.kind == kind }
        Section(title) {
            if items.isEmpty {
                Text("None yet").font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(items) { asset in
                Label {
                    HStack(spacing: 4) {
                        Text(asset.name).lineLimit(1)
                        Spacer()
                        if asset.synced {
                            Text("claude.ai").font(.caption2).foregroundStyle(.tertiary)
                        } else if asset.inProject {
                            Text("project").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                } icon: { Image(systemName: icon) }
                .tag(Item.asset(asset))
            }
        }
    }

    // MARK: Detail

    private var detail: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                if text != saved { Text("Edited").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if let file = fileURL {
                    Button("Show in Finder") {
                        if FileManager.default.fileExists(atPath: file.path) {
                            NSWorkspace.shared.activateFileViewerSelecting([file])
                        } else {
                            NSWorkspace.shared.open(file.deletingLastPathComponent())
                        }
                    }
                    .controlSize(.small)
                }
                if !readOnly {
                    Button("Revert") { text = saved }
                        .controlSize(.small)
                        .disabled(text == saved)
                    Button("Save") { save() }
                        .keyboardShortcut("s")
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(text == saved)
                }
            }
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .disabled(readOnly)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty && !readOnly {
                        Text(placeholder)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(16)
    }

    private var title: String {
        switch selection {
        case .claudeGlobal: return "CLAUDE.md for every project"
        case .omuxGlobal: return "omux instructions for every session"
        case .claudeProject: return "CLAUDE.md for \(group?.name ?? "this project")"
        case .omuxProject: return "omux instructions for \(group?.name ?? "this project")"
        case .asset(let a)?: return "\(a.kind == .skill ? "Skill" : "Agent"): \(a.name)"
        case nil: return ""
        }
    }

    private var explanation: String {
        let timing = "Applies to conversations started after you save; a conversation in progress keeps what it began with."
        switch selection {
        case .claudeGlobal:
            return "~/.claude/CLAUDE.md. Claude Code reads it in every session, in omux or not. \(timing)"
        case .omuxGlobal:
            return "Added to every Claude session omux starts, and only those: running claude elsewhere doesn't see it. Good for things like “I run several sessions at once; keep answers short.” \(timing)"
        case .claudeProject:
            return "CLAUDE.md in the project folder. Claude Code reads it in this project, in omux or not. It's often committed with the code, so it's shared with anyone using the repository. \(timing)"
        case .omuxProject:
            return "Added after the global omux instructions to sessions omux starts in this project. Stored in omux, not in the project folder. \(timing)"
        case .asset(let a)?:
            if a.synced { return "Synced from your claude.ai account. Claude replaces this file when it syncs, so edit the skill on claude.ai instead." }
            let place = a.inProject ? "this project's .claude folder" : "~/.claude, so every session can use it"
            return a.kind == .skill
                ? "In \(place). Claude uses a skill when its description matches the task, or when you type /\(a.name). New sessions pick up changes."
                : "In \(place). Claude can hand work to this agent when its description fits. New sessions pick up changes."
        case nil:
            return ""
        }
    }

    private var placeholder: String {
        switch selection {
        case .claudeGlobal, .claudeProject: return "e.g. Use pnpm, not npm. Write tests for every change."
        case .omuxGlobal, .omuxProject: return "e.g. Several sessions run in parallel; keep replies short."
        default: return ""
        }
    }

    private var readOnly: Bool {
        if case .asset(let a)? = selection { return a.synced }
        return selection == nil
    }

    private var fileURL: URL? {
        switch selection {
        case .claudeGlobal: return Self.claudeHome.appendingPathComponent("CLAUDE.md")
        case .claudeProject: return projectDir?.appendingPathComponent("CLAUDE.md")
        case .omuxGlobal: return OmuxInstructions.globalURL
        case .asset(let a)?: return a.file
        default: return nil
        }
    }

    // MARK: Loading and saving

    private func reloadAssets() {
        var found = ClaudeAsset.scan(Self.claudeHome, inProject: false)
        if let projectDir { found += ClaudeAsset.scan(projectDir.appendingPathComponent(".claude"), inProject: true) }
        assets = found
    }

    private func load() {
        let value: String
        switch selection {
        case .omuxGlobal: value = OmuxInstructions.global
        case .omuxProject: value = group?.instructions ?? ""
        default: value = fileURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        }
        text = value
        saved = value
    }

    private func saveIfNeeded() {
        if text != saved, !readOnly { save() }
    }

    private func save() {
        switch selection {
        case .omuxGlobal:
            OmuxInstructions.global = text
        case .omuxProject:
            if let id = group?.id {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                store.updateGroup(id) { $0.instructions = trimmed.isEmpty ? nil : text }
            }
        default:
            guard let file = fileURL else { return }
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard (try? text.write(to: file, atomically: true, encoding: .utf8)) != nil else { NSSound.beep(); return }
        }
        saved = text
    }

    private func create(_ kind: ClaudeAsset.Kind, name: String, inProject: Bool) {
        let root = inProject ? projectDir?.appendingPathComponent(".claude") : Self.claudeHome
        guard let root else { return }
        saveIfNeeded()
        do {
            let file = try ClaudeAsset.create(kind, named: name, in: root)
            reloadAssets()
            selection = assets.first { $0.file.path == file.path }.map(Item.asset)
        } catch {
            NSSound.beep()
        }
    }
}

extension ClaudeAsset.Kind: Identifiable {
    var id: Self { self }
}

/// Names a new skill or agent and picks where it lives.
private struct NewAssetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let kind: ClaudeAsset.Kind
    let hasProject: Bool
    let create: (String, Bool) -> Void
    @State private var name = ""
    @State private var inProject = false

    /// Claude Code names are lowercase words joined by hyphens.
    private var slug: String {
        name.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    var body: some View {
        Form {
            TextField(kind == .skill ? "Skill name" : "Agent name", text: $name,
                      prompt: Text(kind == .skill ? "release-notes" : "code-reviewer"))
            if !slug.isEmpty, slug != name {
                Text("Saved as “\(slug)”").font(.caption).foregroundStyle(.secondary)
            }
            if hasProject {
                Picker("Available in", selection: $inProject) {
                    Text("Every project").tag(false)
                    Text("This project only").tag(true)
                }
                .pickerStyle(.radioGroup)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create") { create(slug, inProject); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(slug.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
