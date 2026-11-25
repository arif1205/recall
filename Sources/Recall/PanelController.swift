import AppKit
import Combine
import Quartz
import RecallCore
import SwiftUI

/// Non-activating panels can't take key by default; the search field needs key to receive typing.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }

    // Quick Look finds its data source by walking the responder chain to this window.
    weak var quickLook: QLPreviewPanelDataSource?
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { quickLook != nil }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = quickLook
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let model: PanelModel
    private let panel: KeyablePanel
    private var keyMonitor: Any?
    private var previewURLs: [URL] = []
    private var selectionSub: AnyCancellable?
    /// Clip contents shown in Quick Look; wiped on every preview and on close so copies don't linger on disk.
    private let previewDir = FileManager.default.temporaryDirectory.appendingPathComponent("RecallQuickLook")
    /// Where the menu bar icon is, so a hotkey open lands under it too.
    var anchor: () -> NSRect? = { nil }

    static let width: CGFloat = 380
    static let preferredHeight: CGFloat = 760

    init(model: PanelModel) {
        self.model = model
        panel = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.preferredHeight),
                             styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                             backing: .buffered, defer: true)
        super.init()
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        let host = NSHostingView(rootView: PanelView(model: model, store: model.store, settings: model.settings))
        host.safeAreaRegions = [] // the hidden title bar would otherwise leave an empty strip at the top
        host.sizingOptions = [] // the panel sets its own size; don't let SwiftUI content resize it
        panel.contentView = host
        panel.quickLook = self
        selectionSub = model.$selection.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self, self.quickLookVisible else { return }
            self.loadPreview()
            QLPreviewPanel.shared().reloadData()
        }
        model.onClose = { [weak self] in self?.hide() }
        model.onDetachChanged = { [weak self] in self?.applyMode() }
        applyMode()
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible && !model.detached ? hide() : show() }

    func show() {
        model.paster.rememberFrontApp()
        model.willShow()
        if !model.detached { position() }
        panel.makeKeyAndOrderFront(nil)
        // AppKit would otherwise make the search field first responder; the user wants no focus on open.
        DispatchQueue.main.async { self.panel.makeFirstResponder(nil) }
        startKeys()
    }

    func hide() {
        if quickLookVisible { QLPreviewPanel.shared().orderOut(nil) }
        try? FileManager.default.removeItem(at: previewDir)
        panel.orderOut(nil)
        stopKeys()
    }

    private func applyMode() {
        if model.detached {
            panel.styleMask.insert(.closable)
            panel.level = .normal
        } else {
            panel.styleMask.remove(.closable)
            panel.level = .floating
            position()
        }
        panel.standardWindowButton(.closeButton)?.isHidden = !model.detached
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
    }

    /// Under the menu bar icon, on the screen with the mouse.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        // Tall by default, but never taller than the screen below the menu bar.
        panel.setContentSize(NSSize(width: Self.width, height: min(Self.preferredHeight, area.height - 12)))
        let size = panel.frame.size
        // Icon on another display: use a right-side spot on this one instead.
        let iconX = anchor().flatMap { a in NSMouseInRect(NSPoint(x: a.midX, y: a.midY), screen!.frame, false) ? a.midX : nil }
        let x = min(max((iconX ?? area.maxX - 200) - size.width / 2, area.minX + 8), area.maxX - size.width - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: area.maxY - size.height - 6))
    }

    // Floating panel closes when focus moves elsewhere, like a menu.
    func windowDidResignKey(_ notification: Notification) {
        if !model.detached && !quickLookVisible
            && !NSApp.windows.contains(where: { $0.isKeyWindow && $0 !== panel && $0.isVisible }) {
            hide()
        }
    }

    func windowWillClose(_ notification: Notification) {
        model.detached = false
        applyMode()
        stopKeys()
    }

    // MARK: - Keyboard (design §5.3)

    private func startKeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.panel.isKeyWindow || self.quickLookVisible && QLPreviewPanel.shared().isKeyWindow else { return e }
            return self.handle(e) ? nil : e
        }
    }

    private func stopKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private var searchHasFocus: Bool { panel.firstResponder is NSTextView }

    private func handle(_ e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = e.charactersIgnoringModifiers?.lowercased()
        switch (e.keyCode, mods) {
        case (49, []) where !searchHasFocus: toggleQuickLook() // Space, like Finder
        case (53, []) where quickLookVisible: QLPreviewPanel.shared().orderOut(nil)
        case (53, []) where searchHasFocus: // Esc leaves search first
            model.query = ""
            panel.makeFirstResponder(nil)
        case (53, []): // Esc
            if model.detached { panel.performClose(nil) } else { hide() }
        case (125, []): model.moveSelection(model.rowStep)
        case (126, []): model.moveSelection(-model.rowStep)
        case (123, []) where model.settings.viewMode == .grid && !searchHasFocus: model.moveSelection(-1)
        case (124, []) where model.settings.viewMode == .grid && !searchHasFocus: model.moveSelection(1)
        case (36, []), (76, []): model.paste(model.selected)
        case (36, .shift), (76, .shift): model.paste(model.selected, plain: true)
        // Ignore key repeat: holding ⌫ to clear the search must not wipe clips one by one.
        case (51, []) where model.query.isEmpty && !e.isARepeat, (117, []) where model.query.isEmpty && !e.isARepeat: model.delete(model.selected)
        default:
            // Search starts only from ⌘F or a click (#42); swallow stray letters so they don't beep.
            if !searchHasFocus, mods.isSubset(of: .shift), let ch = e.characters, !ch.isEmpty,
               ch.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value < 0xF700 }) {
                return true
            }
            guard mods == .command else { return false }
            switch key {
            case "c" where (panel.firstResponder as? NSTextView)?.selectedRange().length ?? 0 == 0:
                model.copyOnly(model.selected)
            case "f": model.searchRequests += 1
            case "e": model.edit(model.selected)
            case "p": model.togglePin(model.selected)
            case ",": model.onSettings()
            default: return false
            }
        }
        return true
    }

    // MARK: - Quick Look (#43)

    private var quickLookVisible: Bool { QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible }

    private func toggleQuickLook() {
        if quickLookVisible { QLPreviewPanel.shared().orderOut(nil); return }
        guard loadPreview() else { NSSound.beep(); return }
        QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
    }

    /// Points Quick Look at the selected clip: its files, or its content written to a temp file.
    @discardableResult
    private func loadPreview() -> Bool {
        let fm = FileManager.default
        try? fm.removeItem(at: previewDir)
        previewURLs = []
        guard let clip = model.selected else { return false }
        if clip.kind == .file {
            previewURLs = clip.filePaths.map(URL.init(fileURLWithPath:)).filter { fm.fileExists(atPath: $0.path) }
            return !previewURLs.isEmpty
        }
        let formats = model.store.data(for: clip.id) ?? [:]
        let candidates: [(type: String, ext: String)] = clip.kind == .image
            ? [("public.png", "png"), ("public.jpeg", "jpg"), ("public.tiff", "tiff")]
            : clip.kind == .rich ? [("public.rtf", "rtf"), ("public.html", "html")] : []
        let file: (Data, String)? = candidates.lazy.compactMap { c in formats[c.type].map { ($0, c.ext) } }.first
            ?? clip.plainText.map { (Data($0.utf8), clip.kind == .markdown ? "md" : "txt") }
        guard let (data, ext) = file else { return false }
        try? fm.createDirectory(at: previewDir, withIntermediateDirectories: true)
        let url = previewDir.appendingPathComponent("\(clip.kind.label).\(ext)")
        guard (try? data.write(to: url)) != nil else { return false }
        previewURLs = [url]
        return true
    }
}

extension PanelController: QLPreviewPanelDataSource {
    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { previewURLs.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated { previewURLs[index] as NSURL }
    }
}
