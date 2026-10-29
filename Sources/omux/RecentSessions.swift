import Foundation

/// A Claude Code conversation found in ~/.claude/projects.
struct RecentSession: Identifiable, Hashable {
    let id: UUID
    let cwd: String
    let prompt: String
    let date: Date
    /// The name Claude Code gave the conversation (or one set with /rename), if any.
    var title: String?

    var folder: String { (cwd as NSString).abbreviatingWithTildeInPath }

    /// The conversation's title, else its first prompt.
    var displayTitle: String { title ?? prompt }

    /// Short name for a tab: the title, else the first words of the first prompt.
    var tabName: String {
        if let title { return title.count > 40 ? String(title.prefix(40)) + "…" : title }
        let words = prompt.split(separator: " ").prefix(5).joined(separator: " ")
        return words.count > 32 ? String(words.prefix(32)) + "…" : words
    }

    private struct Record: Decodable {
        struct Message: Decodable {
            let content: Content?
            enum Content: Decodable {
                case text(String), blocks([Block])
                struct Block: Decodable { let text: String? }
                init(from decoder: Decoder) throws {
                    let c = try decoder.singleValueContainer()
                    if let s = try? c.decode(String.self) { self = .text(s) } else { self = .blocks(try c.decode([Block].self)) }
                }
                var text: String {
                    switch self {
                    case .text(let s): return s
                    case .blocks(let b): return b.compactMap(\.text).joined(separator: " ")
                    }
                }
            }
        }
        let type: String
        let cwd: String?
        let message: Message?
    }

    /// Title records Claude Code appends as a conversation goes on; the last one wins.
    private struct TitleRecord: Decodable {
        let type: String
        let aiTitle: String?
        let customTitle: String?
    }

    /// The newest title in the transcript's tail, preferring a name you gave it.
    private static func title(in handle: FileHandle, decoder: JSONDecoder) -> String? {
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toFileOffset: size > 256 * 1024 ? size - 256 * 1024 : 0)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }
        var ai: String?
        for line in text.split(separator: "\n").reversed() where line.contains("Title\"") {
            guard let record = try? decoder.decode(TitleRecord.self, from: Data(line.utf8)) else { continue }
            if let custom = record.customTitle?.trimmingCharacters(in: .whitespaces), !custom.isEmpty { return custom }
            if ai == nil, let title = record.aiTitle?.trimmingCharacters(in: .whitespaces), !title.isEmpty { ai = title }
        }
        return ai
    }

    /// Scans transcripts, newest first. Reads only the head of each file.
    static func load(limit: Int = 300) -> [RecentSession] {
        let root = URL(fileURLWithPath: NSHomeDirectory() + "/.claude/projects")
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        var files: [(URL, Date)] = []
        for project in projects {
            guard let items = try? fm.contentsOfDirectory(at: project, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for url in items where url.pathExtension == "jsonl" {
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                files.append((url, date))
            }
        }
        files.sort { $0.1 > $1.1 }
        let decoder = JSONDecoder()
        var result: [RecentSession] = []
        for (url, date) in files.prefix(limit) {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  let handle = try? FileHandle(forReadingFrom: url) else { continue }
            let head = handle.readData(ofLength: 128 * 1024)
            let title = title(in: handle, decoder: decoder)
            try? handle.close()
            guard let text = String(data: head, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                guard let record = try? decoder.decode(Record.self, from: Data(line.utf8)),
                      record.type == "user",
                      let cwd = record.cwd,
                      let prompt = record.message?.content?.text.trimmingCharacters(in: .whitespacesAndNewlines),
                      !prompt.isEmpty, !prompt.hasPrefix("<") // skip slash-command and system messages
                else { continue }
                result.append(RecentSession(id: id, cwd: cwd, prompt: prompt.replacingOccurrences(of: "\n", with: " "), date: date, title: title))
                break
            }
        }
        return result
    }
}
