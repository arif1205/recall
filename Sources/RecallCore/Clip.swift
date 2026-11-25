import CryptoKit
import Foundation

public enum Tab: Sendable { case history, pinned }

/// A clipboard snapshot before it is stored.
public struct ClipDraft: Equatable, Sendable {
    public var formats: [String: Data]
    public var plainText: String?
    public var fileURLs: [URL]
    public var kind: ClipKind
    public var contentHash: String
    public var sourceBundleID: String?

    public init(formats: [String: Data], plainText: String?, fileURLs: [URL], kind: ClipKind,
                contentHash: String, sourceBundleID: String?) {
        self.formats = formats
        self.plainText = plainText
        self.fileURLs = fileURLs
        self.kind = kind
        self.contentHash = contentHash
        self.sourceBundleID = sourceBundleID
    }
}

public struct Clip: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: ClipKind
    public var preview: String
    public var plainText: String?
    public var filePaths: [String]
    public var formatTypes: [String]
    public var contentHash: String
    public var pinned: Bool
    public var lastCopiedAt: Date
    public var sourceBundleID: String?
    /// List position: when the clip was first saved. Nil only in indexes written before #40; ClipStore backfills it on load.
    public var addedAt: Date?

    public var position: Date { addedAt ?? lastCopiedAt }
}


/// Duplicate detection key: the clip's main content, so the same text with or without formatting is one clip.
public enum ContentHash {
    public static func of(text: String) -> String { of(data: Data(("t:" + text).utf8)) }
    public static func of(files: [URL]) -> String { of(data: Data(("f:" + files.map(\.path).sorted().joined(separator: "\n")).utf8)) }
    public static func of(data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
