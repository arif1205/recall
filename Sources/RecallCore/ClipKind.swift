import Foundation

public enum ClipKind: String, Codable, CaseIterable, Sendable {
    case text, rich, markdown, code, link, color, image, file, other

    public var label: String {
        switch self {
        case .text: "Text"
        case .rich: "Rich text"
        case .markdown: "Markdown"
        case .code: "Code"
        case .link: "Link"
        case .color: "Colour"
        case .image: "Image"
        case .file: "File"
        case .other: "Other"
        }
    }

    public var isEditable: Bool { ![.image, .file, .other].contains(self) }
}

/// Labels plain text by type. Only a label: clip content is never changed.
public enum Classifier {
    public static func kind(forPlainText raw: String) -> ClipKind {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLink(s) { return .link }
        if colorHex(s) != nil { return .color }
        if isMarkdown(s) { return .markdown }
        if isCode(s) { return .code }
        return .text
    }

    /// Normalised `#RRGGBB` / `#RRGGBBAA`, or nil when `s` is not a hex colour code.
    public static func colorHex(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("#") else { return nil }
        let hex = t.dropFirst().uppercased()
        guard [3, 6, 8].contains(hex.count), hex.allSatisfy(\.isHexDigit) else { return nil }
        return "#" + (hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex)
    }

    private static func isLink(_ s: String) -> Bool {
        guard !s.contains(where: \.isWhitespace), let url = URL(string: s),
              let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "mailto", "file"].contains(scheme)
    }

    private static func isMarkdown(_ s: String) -> Bool {
        let lines = s.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count >= 2 else { return false }
        let pattern = #"^(#{1,6} |[-*] |\d+\. |```)|\[[^\]]+\]\([^)]+\)"#
        return lines.contains { $0.range(of: pattern, options: .regularExpression) != nil }
    }

    private static let codeTokens = ["{", "}", ";", "=>", "func ", "def ", "class ", "const ", "let ",
                                     "var ", "import ", "return ", "()", "==", "</", "/>"]

    private static func isCode(_ s: String) -> Bool {
        codeTokens.filter { s.contains($0) }.count >= 2
    }
}
