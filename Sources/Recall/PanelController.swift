import AppKit
import RecallCore
import SwiftUI

/// Non-activating panels can't take key by default; the search field needs key to receive typing.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let model: PanelModel
    private let panel: KeyablePanel
    private var keyMonitor: Any?
    /// Where the menu bar icon is, so a hotkey open lands under it too.
    var anchor: () -> NSRect? = { nil }

    init(model: PanelModel) {
        self.model = model
        panel = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 560),
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
        panel.contentView = NSHostingView(rootView: PanelView(model: model, store: model.store, settings: model.settings))
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
        startKeys()
    }

    func hide() {
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
        let size = panel.frame.size
        // Icon on another display: use a right-side spot on this one instead.
        let iconX = anchor().flatMap { a in NSMouseInRect(NSPoint(x: a.midX, y: a.midY), screen!.frame, false) ? a.midX : nil }
        let x = min(max((iconX ?? area.maxX - 200) - size.width / 2, area.minX + 8), area.maxX - size.width - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: area.maxY - size.height - 6))
    }

    // Floating panel closes when focus moves elsewhere, like a menu.
    func windowDidResignKey(_ notification: Notification) {
        if !model.detached && !NSApp.windows.contains(where: { $0.isKeyWindow && $0 !== panel && $0.isVisible }) {
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
            guard let self, self.panel.isKeyWindow else { return e }
            return self.handle(e) ? nil : e
        }
    }

    private func stopKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handle(_ e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = e.charactersIgnoringModifiers?.lowercased()
        switch (e.keyCode, mods) {
        case (53, []): // Esc
            if model.detached { panel.performClose(nil) } else { hide() }
        case (125, []): model.moveSelection(1)
        case (126, []): model.moveSelection(-1)
        case (36, []), (76, []): model.paste(model.selected)
        case (36, .shift), (76, .shift): model.paste(model.selected, plain: true)
        case (51, []) where model.query.isEmpty, (117, []) where model.query.isEmpty: model.delete(model.selected)
        default:
            guard mods == .command else { return false }
            switch key {
            case "c" where (panel.firstResponder as? NSTextView)?.selectedRange().length ?? 0 == 0:
                model.copyOnly(model.selected)
            case "e": model.edit(model.selected)
            case "p": model.togglePin(model.selected)
            case ",": model.onSettings()
            default: return false
            }
        }
        return true
    }
}
