import AppKit
import Foundation

/// Clip history: index in `index.json`, each format's bytes in `data/<id>/<n>.bin`.
@MainActor
public final class ClipStore: ObservableObject {
    @Published public private(set) var clips: [Clip] = []
    public var historyLimit: Int = 200 { didSet { if trim() > 0 { save() } } }

    private let dir: URL
    private let now: () -> Date
    private let fm = FileManager.default
    private var indexURL: URL { dir.appendingPathComponent("index.json") }

    public init(directory: URL, now: @escaping () -> Date = Date.init) {
        dir = directory
        self.now = now
        try? fm.createDirectory(at: dir.appendingPathComponent("data"), withIntermediateDirectories: true)
        load()
    }

    @discardableResult
    public func add(_ d: ClipDraft) -> Clip {
        if let i = clips.firstIndex(where: { $0.contentHash == d.contentHash }) {
            var c = clips[i]
            c.kind = d.kind
            c.preview = Self.preview(for: d)
            c.plainText = d.plainText
            c.filePaths = d.fileURLs.map(\.path)
            c.formatTypes = writeData(d.formats, id: c.id)
            c.lastCopiedAt = now()
            c.sourceBundleID = d.sourceBundleID
            clips[i] = c
            save()
            return c
        }
        let id = UUID()
        let c = Clip(id: id, kind: d.kind, preview: Self.preview(for: d), plainText: d.plainText,
                     filePaths: d.fileURLs.map(\.path), formatTypes: writeData(d.formats, id: id),
                     contentHash: d.contentHash, pinned: false, lastCopiedAt: now(),
                     sourceBundleID: d.sourceBundleID)
        clips.append(c)
        trim()
        save()
        return c
    }

    public func touch(_ id: UUID) { mutate(id) { $0.lastCopiedAt = now() } }

    public func setPinned(_ id: UUID, _ pinned: Bool) {
        mutate(id) { $0.pinned = pinned }
        if !pinned, trim() > 0 { save() }
    }

    public func delete(_ id: UUID) {
        clips.removeAll { $0.id == id }
        removeData(id)
        save()
    }

    /// Editing always stores plain text (rich formatting is dropped, #23); position is kept.
    public func updateText(_ id: UUID, _ text: String) {
        let formats = ["public.utf8-plain-text": Data(text.utf8)]
        mutate(id) { c in
            c.plainText = text
            c.kind = Classifier.kind(forPlainText: text)
            c.preview = Self.firstLine(text)
            c.contentHash = ContentHash.of(text: text)
            c.formatTypes = writeData(formats, id: id)
        }
    }

    public func clearHistory() {
        for c in clips where !c.pinned { removeData(c.id) }
        clips.removeAll { !$0.pinned }
        save()
    }

    public func overflow(ifLimit limit: Int) -> Int { max(0, clips.filter { !$0.pinned }.count - limit) }

    public func list(_ tab: Tab, query: String) -> [Clip] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return clips
            .filter { tab == .history || $0.pinned }
            .filter { q.isEmpty || Self.searchText($0).contains(q) }
            .sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    }

    public func data(for id: UUID) -> [String: Data]? {
        guard let c = clips.first(where: { $0.id == id }) else { return nil }
        var out: [String: Data] = [:]
        for (n, type) in c.formatTypes.enumerated() {
            guard let d = try? Data(contentsOf: dataDir(id).appendingPathComponent("\(n).bin")) else { return nil }
            out[type] = d
        }
        return out
    }

    // MARK: - Private

    private func mutate(_ id: UUID, _ change: (inout Clip) -> Void) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        change(&clips[i])
        save()
    }

    /// Drops the oldest unpinned clips beyond the limit; pinned clips are never trimmed (#16).
    @discardableResult
    private func trim() -> Int {
        let drop = clips.filter { !$0.pinned }.sorted { $0.lastCopiedAt > $1.lastCopiedAt }.dropFirst(historyLimit)
        let ids = Set(drop.map(\.id))
        ids.forEach(removeData)
        clips.removeAll { ids.contains($0.id) }
        return ids.count
    }

    private func dataDir(_ id: UUID) -> URL { dir.appendingPathComponent("data/\(id.uuidString)") }

    private func writeData(_ formats: [String: Data], id: UUID) -> [String] {
        let d = dataDir(id)
        try? fm.removeItem(at: d)
        try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        let types = formats.keys.sorted()
        for (n, t) in types.enumerated() {
            try? formats[t]!.write(to: d.appendingPathComponent("\(n).bin"), options: .atomic)
        }
        return types
    }

    private func removeData(_ id: UUID) { try? fm.removeItem(at: dataDir(id)) }

    private func load() {
        guard let raw = try? Data(contentsOf: indexURL) else { return }
        if let decoded = try? JSONDecoder().decode([Clip].self, from: raw) {
            clips = decoded
        } else {
            // Keep the unreadable file for recovery instead of overwriting it on the next save.
            let bad = dir.appendingPathComponent("index.json.corrupt")
            try? fm.removeItem(at: bad)
            try? fm.moveItem(at: indexURL, to: bad)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(clips) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private static func firstLine(_ s: String) -> String {
        let line = s.split(whereSeparator: \.isNewline).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return String((line.map(String.init) ?? s).trimmingCharacters(in: .whitespaces).prefix(200))
    }

    static func preview(for d: ClipDraft) -> String {
        if !d.fileURLs.isEmpty { return d.fileURLs.map(\.lastPathComponent).joined(separator: ", ") }
        if let t = d.plainText, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return firstLine(t) }
        if d.kind == .image, let img = d.formats.values.lazy.compactMap(NSImage.init(data:)).first,
           let rep = img.representations.first {
            return "Image \(rep.pixelsWide)×\(rep.pixelsHigh)"
        }
        return d.formats.keys.sorted().first ?? "Clip"
    }

    private static func searchText(_ c: Clip) -> String {
        ([c.preview, c.plainText ?? ""] + c.filePaths).joined(separator: "\n").lowercased()
    }
}
