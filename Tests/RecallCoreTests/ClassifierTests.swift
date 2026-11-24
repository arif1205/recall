import Testing
@testable import RecallCore

@Test func link() { #expect(Classifier.kind(forPlainText: "https://github.com/apple/swift") == .link) }
@Test func linkNeedsScheme() { #expect(Classifier.kind(forPlainText: "github.com is nice") == .text) }
@Test func color() {
    #expect(Classifier.kind(forPlainText: "#FF5733") == .color)
    #expect(Classifier.colorHex(" #f53 ") == "#FF5533")
    #expect(Classifier.colorHex("#FF573") == nil)
}
@Test func markdown() { #expect(Classifier.kind(forPlainText: "## Notes\n- one\n- two") == .markdown) }
@Test func code() {
    #expect(Classifier.kind(forPlainText: "func a() {\n  return 1\n}") == .code)
    #expect(Classifier.kind(forPlainText: "const x = items.filter(i => i.ok);") == .code)
}
@Test func plain() { #expect(Classifier.kind(forPlainText: "Meeting moved to Thursday.") == .text) }
