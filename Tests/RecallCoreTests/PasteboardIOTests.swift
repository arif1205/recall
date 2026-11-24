import AppKit
import Testing
@testable import RecallCore

// NSPasteboard deadlocks when several tests hit the pasteboard server at once.
@Suite(.serialized) @MainActor
struct PasteboardIOTests {
    let pb = NSPasteboard(name: .init("recall-test-\(UUID().uuidString)"))
    let plain = NSPasteboard.PasteboardType.string
    let rtf = NSPasteboard.PasteboardType.rtf

    func draft(_ r: ReadResult) -> ClipDraft? { if case .clip(let d) = r { d } else { nil } }

    @Test func plainText() {
        pb.clearContents(); pb.setString("hi", forType: plain)
        let d = draft(PasteboardReader.read(pb, sourceBundleID: "com.apple.Notes"))
        #expect(d?.kind == .text)
        #expect(d?.plainText == "hi")
        #expect(d?.sourceBundleID == "com.apple.Notes")
    }

    @Test func empty() {
        pb.clearContents()
        #expect(PasteboardReader.read(pb, sourceBundleID: nil) == .empty)
    }

    @Test func concealedSkipped() {
        pb.clearContents()
        pb.declareTypes([plain, .init("org.nspasteboard.ConcealedType")], owner: nil)
        pb.setString("secret", forType: plain)
        pb.setString("", forType: .init("org.nspasteboard.ConcealedType"))
        #expect(PasteboardReader.read(pb, sourceBundleID: nil) == .concealed)
    }

    @Test func tooLarge() {
        pb.clearContents()
        pb.setData(Data(count: 26 * 1024 * 1024), forType: .png)
        #expect(PasteboardReader.read(pb, sourceBundleID: nil) == .tooLarge)
    }

    @Test func ownWriteIgnored() {
        PasteboardWriter.write(formats: [plain.rawValue: Data("x".utf8)], plainOnly: false, to: pb)
        #expect(PasteboardReader.read(pb, sourceBundleID: nil) == .ownWrite)
    }

    @Test func richKeepsAllFormats() throws {
        let rtfData = try #require(NSAttributedString(string: "bold").rtf(from: NSRange(location: 0, length: 4), documentAttributes: [:]))
        pb.clearContents(); pb.declareTypes([rtf, plain], owner: nil)
        pb.setData(rtfData, forType: rtf); pb.setString("bold", forType: plain)
        let d = draft(PasteboardReader.read(pb, sourceBundleID: nil))
        #expect(d?.kind == .rich)
        let keys = Set(d?.formats.keys.map { $0 } ?? [])
        #expect(keys.isSuperset(of: [rtf.rawValue, plain.rawValue]))
    }

    @Test func sameTextSameHash() throws {
        pb.clearContents(); pb.setString("hi", forType: plain)
        let a = draft(PasteboardReader.read(pb, sourceBundleID: nil))
        let rtfData = try #require(NSAttributedString(string: "hi").rtf(from: NSRange(location: 0, length: 2), documentAttributes: [:]))
        pb.clearContents(); pb.declareTypes([rtf, plain], owner: nil)
        pb.setData(rtfData, forType: rtf); pb.setString("hi", forType: plain)
        let b = draft(PasteboardReader.read(pb, sourceBundleID: nil))
        #expect(a?.contentHash != nil && a?.contentHash == b?.contentHash)
    }

    @Test func plainOnlyWrite() {
        PasteboardWriter.write(formats: [rtf.rawValue: Data("{\\rtf1 x}".utf8), plain.rawValue: Data("x".utf8)],
                               plainOnly: true, to: pb)
        let types = Set(pb.types ?? [])
        #expect(types.contains(plain) && types.contains(PasteboardWriter.ownType))
        #expect(!types.contains(rtf))
        #expect(pb.string(forType: plain) == "x")
    }

    @Test func multipleFiles() {
        let a = URL(fileURLWithPath: "/tmp/a.txt"), b = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID()).pdf")
        pb.clearContents(); pb.writeObjects([a as NSURL, b as NSURL])
        let d = draft(PasteboardReader.read(pb, sourceBundleID: nil))
        #expect(d?.kind == .file)
        #expect(d?.fileURLs.map(\.path) == [a.path, b.path])
    }

    @Test func writeFilesBack() {
        let b = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID()).pdf")
        pb.clearContents(); pb.writeObjects([b as NSURL])
        guard let d = draft(PasteboardReader.read(pb, sourceBundleID: nil)) else { Issue.record("no draft"); return }
        PasteboardWriter.write(formats: d.formats, plainOnly: false, to: pb)
        let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL]
        #expect(urls?.map(\.path) == [b.path])
    }
}
