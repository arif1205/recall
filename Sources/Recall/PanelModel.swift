import AppKit
import RecallCore

/// UI state for the clip panel, shared by the SwiftUI view and the panel's key handling.
@MainActor
final class PanelModel: ObservableObject {
    let store: ClipStore
    let settings: Settings
    let paster: Paster

    // Only on a real change: the search field rewrites the same text when it loses focus on open.
    @Published var tab: Tab = .history { didSet { if tab != oldValue { selection = visible.first?.id } } }
    @Published var query = "" { didSet { if query != oldValue { selection = visible.first?.id } } }
    @Published var selection: UUID? { didSet { if selection != copiedID { copiedID = nil } } }
    @Published var detached = false
    @Published var notice: String?
    @Published var needsAccessibility = false
    /// Clip copied with ⌘C; its outline stays green until the selection moves (#41).
    @Published private(set) var copiedID: UUID?
    /// Bumped on each open so the list scrolls to the selection even when it didn't change.
    @Published private(set) var openCount = 0
    /// Bumped by ⌘F; the view focuses the search field.
    @Published var searchRequests = 0

    var onClose: () -> Void = {}
    var onEdit: (Clip) -> Void = { _ in }
    var onSettings: () -> Void = {}
    var onDetachChanged: () -> Void = {}
    var onMonitoringChanged: () -> Void = {}

    private var thumbs: [UUID: NSImage] = [:]
    private var appIcons: [String: NSImage] = [:]

    init(store: ClipStore, settings: Settings, paster: Paster) {
        self.store = store
        self.settings = settings
        self.paster = paster
    }

    var visible: [Clip] { store.list(tab, query: query) }
    var selected: Clip? { visible.first { $0.id == selection } ?? visible.first }

    func willShow() {
        query = ""
        notice = nil
        copiedID = nil
        needsAccessibility = !paster.hasAccessibility
        // Clips keep their position when re-copied (#40), so the current clipboard may sit mid-list.
        selection = visible.max { $0.lastCopiedAt < $1.lastCopiedAt }?.id
        openCount += 1
    }

    func moveSelection(_ delta: Int) {
        let list = visible
        guard !list.isEmpty else { return }
        let i = list.firstIndex { $0.id == selection } ?? 0
        selection = list[max(0, min(list.count - 1, i + delta))].id
    }

    func paste(_ clip: Clip?, plain: Bool = false) {
        guard let clip else { return }
        switch paster.paste(clip, plain: plain && clip.kind == .rich, store: store) {
        case .dataMissing:
            notice = "Clip data missing — removed"
        case .pasted, .copiedOnly:
            if !detached { onClose() }
            needsAccessibility = !paster.hasAccessibility
        }
    }

    func copyOnly(_ clip: Clip?) {
        guard let clip else { return }
        guard paster.paste(clip, plain: false, store: store, sendKeys: false) != .dataMissing else {
            notice = "Clip data missing — removed"
            return
        }
        notice = nil
        copiedID = clip.id
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: "Copied", .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func togglePin(_ clip: Clip?) {
        guard let clip else { return }
        store.setPinned(clip.id, !clip.pinned)
    }

    func delete(_ clip: Clip?) {
        guard let clip else { return }
        let list = visible
        let i = list.firstIndex { $0.id == clip.id } ?? 0
        store.delete(clip.id)
        let rest = visible
        selection = rest.isEmpty ? nil : rest[min(i, rest.count - 1)].id
    }

    func edit(_ clip: Clip?) {
        guard let clip, clip.kind.isEditable else { return }
        onEdit(clip)
    }

    func toggleMonitoring() {
        settings.monitoring.toggle()
        onMonitoringChanged()
    }

    func appIcon(_ bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let i = appIcons[bundleID] { return i }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons[bundleID] = icon
        return icon
    }

    /// Grid moves by row with ↑/↓ (two columns) and by item with ←/→.
    var rowStep: Int { settings.viewMode == .grid ? 2 : 1 }

    func thumbnail(_ clip: Clip) -> NSImage? {
        if let t = thumbs[clip.id] { return t }
        guard let data = store.data(for: clip.id),
              let raw = ["public.png", "public.tiff", "public.jpeg"].compactMap({ data[$0] }).first,
              let img = NSImage(data: raw) else { return nil }
        thumbs[clip.id] = img
        return img
    }
}
