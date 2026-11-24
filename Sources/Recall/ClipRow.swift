import AppKit
import RecallCore
import SwiftUI

struct ClipRow: View {
    let clip: Clip
    let selected: Bool
    let showPin: Bool
    @ObservedObject var model: PanelModel

    private static let ago: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(clip.preview).lineLimit(1).truncationMode(.tail)
                Text("\(clip.kind.label) · \(Self.ago.localizedString(for: clip.lastCopiedAt, relativeTo: .now))")
                    .font(.system(size: 11))
                    .foregroundStyle(selected ? Color.white.opacity(0.8) : .secondary)
            }
            Spacer(minLength: 0)
            if showPin && clip.pinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                    .accessibilityLabel("Pinned")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor : .clear))
        .contentShape(Rectangle())
    }

    @ViewBuilder private var icon: some View {
        switch clip.kind {
        case .color:
            Circle().fill(Color(hex: Classifier.colorHex(clip.plainText ?? "") ?? "#888888"))
                .overlay(Circle().stroke(Color.white.opacity(0.4)))
                .frame(width: 18, height: 18)
        case .image:
            if let img = model.thumbnail(clip) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                symbol("photo")
            }
        case .file:
            Image(nsImage: NSWorkspace.shared.icon(forFile: clip.filePaths.first ?? "/")).resizable()
                .frame(width: 22, height: 22)
        case .text: symbol("text.alignleft")
        case .rich: symbol("textformat")
        case .markdown: symbol("number")
        case .code: symbol("chevron.left.forwardslash.chevron.right")
        case .link: symbol("link")
        case .other: symbol("doc")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            .accessibilityLabel(clip.kind.label)
    }
}

extension Color {
    /// `#RRGGBB` or `#RRGGBBAA`, as produced by `Classifier.colorHex`.
    init(hex: String) {
        let v = UInt64(hex.dropFirst(), radix: 16) ?? 0
        let hasAlpha = hex.count == 9
        let r = Double((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = Double((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = Double((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? Double(v & 0xFF) / 255 : 1
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Card used by the Grid (compact) and Expanded (full-width, more detail) views.
struct ClipCard: View {
    let clip: Clip
    let selected: Bool
    let expanded: Bool
    @ObservedObject var model: PanelModel

    private static let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    private static let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy/M/d"; return f }()

    private var stamp: String {
        Calendar.current.isDateInToday(clip.lastCopiedAt)
            ? Self.timeFmt.string(from: clip.lastCopiedAt) : Self.dateFmt.string(from: clip.lastCopiedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if expanded, let icon = model.appIcon(clip.sourceBundleID) {
                    Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                }
                if expanded {
                    Text(clip.kind.label).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if clip.pinned { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.secondary) }
                Text(stamp).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(height: expanded ? nil : 150, alignment: .top)
        .frame(minHeight: expanded ? 70 : nil, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(selected ? 0.16 : 0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(clip.kind.label): \(clip.preview)")
    }

    @ViewBuilder private var content: some View {
        switch clip.kind {
        case .image:
            if let img = model.thumbnail(clip) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: expanded ? 180 : 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Label(clip.preview, systemImage: "photo").foregroundStyle(.secondary)
            }
        case .color:
            let hex = Classifier.colorHex(clip.plainText ?? "") ?? "#888888"
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: hex)).frame(height: expanded ? 48 : 60)
                Text(clip.preview).font(.system(size: 12, design: .monospaced))
            }
        case .file:
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: clip.filePaths.first ?? "/")).resizable()
                    .frame(width: expanded ? 40 : 32, height: expanded ? 40 : 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.preview).lineLimit(2)
                    if expanded, let path = clip.filePaths.first {
                        Text((path as NSString).deletingLastPathComponent).font(.system(size: 11))
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
            }
        case .code, .markdown:
            Text(clip.plainText ?? clip.preview)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(expanded ? 8 : 6)
        default:
            Text(clip.plainText ?? clip.preview)
                .font(.system(size: 13))
                .lineLimit(expanded ? 6 : 5)
        }
    }
}
