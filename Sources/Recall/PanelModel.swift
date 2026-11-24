import AppKit
import RecallCore

/// UI state for the clip panel, shared by the SwiftUI view and the panel's key handling.
@MainActor
final class PanelModel: ObservableObject {
    let store: ClipStore
    let settings: Settings
    let paster: Paster

    @Published var tab: Tab = .history { didSet { selection = visible.first?.id } }
    @Published var query = "" { didSet { selection = visible.first?.id } }
    @Published var selection: UUID?
    @Published var detached = false
    @Published var notice: String?
    @Published var needsAccessibility = false

    var onClose: () -> Void = {}
    var onEdit: (Clip) -> Void = { _ in }
    var onSettings: () -> Void = {}
    var onDetachChanged: () -> Void = {}
    var onMonitoringChanged: () -> Void = {}

    private var thumbs: [UUID: NSImage] = [:]

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
        needsAccessibility = !paster.hasAccessibility
        selection = visible.first?.id
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
        notice = paster.paste(clip, plain: false, store: store, sendKeys: false) == .dataMissing
            ? "Clip data missing — removed" : "Copied — not pasted"
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

    func thumbnail(_ clip: Clip) -> NSImage? {
        if let t = thumbs[clip.id] { return t }
        guard let data = store.data(for: clip.id),
              let raw = ["public.png", "public.tiff", "public.jpeg"].compactMap({ data[$0] }).first,
              let img = NSImage(data: raw) else { return nil }
        thumbs[clip.id] = img
        return img
    }
}
