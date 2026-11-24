import Foundation
import Testing
@testable import RecallCore

@MainActor
struct ClipStoreTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("recall-\(UUID().uuidString)")
    var clock = Clock()

    final class Clock: @unchecked Sendable {
        var t = Date(timeIntervalSince1970: 1_000_000)
        func tick() -> Date { t = t.addingTimeInterval(1); return t }
    }

    func store() -> ClipStore { ClipStore(directory: dir, now: clock.tick) }

    func draft(_ text: String) -> ClipDraft {
        ClipDraft(formats: ["public.utf8-plain-text": Data(text.utf8)], plainText: text, fileURLs: [],
                  kind: Classifier.kind(forPlainText: text), contentHash: "h-\(text)", sourceBundleID: nil)
    }

    @Test func newestFirst() {
        let s = store()
        s.add(draft("a")); s.add(draft("b"))
        #expect(s.list(.history, query: "").map(\.preview) == ["b", "a"])
    }

    @Test func duplicateMovesToTop() {
        let s = store()
        s.add(draft("a")); s.add(draft("b")); s.add(draft("a"))
        #expect(s.list(.history, query: "").map(\.preview) == ["a", "b"])
    }

    @Test func trimKeepsPinned() {
        let s = store()
        s.historyLimit = 10
        let first = s.add(draft("keep"))
        s.setPinned(first.id, true)
        for i in 0..<12 { s.add(draft("n\(i)")) }
        #expect(s.clips.filter { !$0.pinned }.count == 10)
        #expect(s.clips.contains { $0.id == first.id })
    }

    @Test func clearKeepsPinned() {
        let s = store()
        let a = s.add(draft("a")); s.add(draft("b")); s.add(draft("c"))
        s.setPinned(a.id, true)
        s.clearHistory()
        #expect(s.clips.map(\.id) == [a.id])
    }

    @Test func pinnedInBothTabs() {
        let s = store()
        let a = s.add(draft("a")); s.add(draft("b"))
        s.setPinned(a.id, true)
        #expect(s.list(.history, query: "").contains { $0.id == a.id })
        #expect(s.list(.pinned, query: "").map(\.id) == [a.id])
    }

    @Test func searchCaseInsensitive() {
        let s = store()
        s.add(draft("Hello World")); s.add(draft("other"))
        let file = URL(fileURLWithPath: "/tmp/report-q4.pdf")
        s.add(ClipDraft(formats: ["public.file-url": Data(file.absoluteString.utf8)], plainText: nil,
                        fileURLs: [file], kind: .file, contentHash: "f", sourceBundleID: nil))
        #expect(s.list(.history, query: "hello").map(\.preview) == ["Hello World"])
        #expect(s.list(.history, query: "REPORT").map(\.kind) == [.file])
    }

    @Test func editKeepsPosition() {
        let s = store()
        s.add(draft("a")); let b = s.add(draft("b")); s.add(draft("c"))
        s.updateText(b.id, "https://example.com")
        let list = s.list(.history, query: "")
        #expect(list.map(\.preview) == ["c", "https://example.com", "a"])
        #expect(list[1].kind == .link)
        #expect(s.data(for: b.id)?["public.utf8-plain-text"] == Data("https://example.com".utf8))
    }

    @Test func persistsAcrossInit() {
        let a = store().add(draft("saved"))
        let again = store()
        #expect(again.clips.map(\.id) == [a.id])
        #expect(again.data(for: a.id)?["public.utf8-plain-text"] == Data("saved".utf8))
    }

    @Test func corruptIndexIsRenamed() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: dir.appendingPathComponent("index.json"))
        let s = store()
        #expect(s.clips.isEmpty)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("index.json.corrupt").path))
    }

    @Test func missingDataReturnsNil() throws {
        let s = store()
        let a = s.add(draft("x"))
        try FileManager.default.removeItem(at: dir.appendingPathComponent("data/\(a.id.uuidString)"))
        #expect(s.data(for: a.id) == nil)
    }

    @Test func overflowCount() {
        let s = store()
        for i in 0..<15 { s.add(draft("n\(i)")) }
        #expect(s.overflow(ifLimit: 10) == 5)
    }

    @Test func lowerLimitTrims() {
        let s = store()
        for i in 0..<15 { s.add(draft("n\(i)")) }
        s.historyLimit = 10
        #expect(s.clips.count == 10)
        #expect(s.list(.history, query: "").first?.preview == "n14")
    }
}
