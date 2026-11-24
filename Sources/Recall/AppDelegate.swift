import AppKit
import Combine
import RecallCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = RecallCore.Settings()
    private var store: ClipStore!
    private var watcher: ClipboardWatcher!
    private let hotkey = HotkeyManager()
    private let paster = Paster()
    private var statusItem: NSStatusItem!
    private var panel: PanelController!
    private let editHost = WindowHost()
    private let settingsHost = WindowHost()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recall")
        store = ClipStore(directory: dir)
        store.historyLimit = settings.historyLimit
        watcher = ClipboardWatcher(store: store, settings: settings)
        watcher.start()

        let model = PanelModel(store: store, settings: settings, paster: paster)
        panel = PanelController(model: model)
        model.onSettings = { [weak self] in self?.openSettings() }
        model.onEdit = { [weak self] clip in self?.openEditor(clip) }
        model.onMonitoringChanged = { [weak self] in self?.monitoringChanged() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Recall")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.setAccessibilityLabel("Recall")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(iconClicked)
        panel.anchor = { [weak self] in
            guard let b = self?.statusItem.button, let w = b.window else { return nil }
            return w.convertToScreen(b.convert(b.bounds, to: nil))
        }
        monitoringChanged()
        watcher.onSaved = { [weak self] in self?.spinIcon() }

        hotkey.onPress = { [weak self] in self?.panel.toggle() }
        _ = hotkey.register(settings.shortcut)

        if !settings.firstLaunchDone {
            LoginItem.set(true) // #11: on by default
            paster.requestAccessibility()
            settings.firstLaunchDone = true
        }
    }

    @objc private func iconClicked() { panel.toggle() }

    private var spinTimer: Timer?

    /// One full turn of the menu bar icon when a copy is saved.
    private func spinIcon() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              spinTimer == nil, let button = statusItem.button, let base = button.image else { return }
        let frames = 18, duration = 0.3
        var i = 0
        spinTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(frames), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                i += 1
                if i >= frames {
                    button.image = base
                    self?.spinTimer?.invalidate()
                    self?.spinTimer = nil
                } else {
                    button.image = base.rotated(by: -360 * CGFloat(i) / CGFloat(frames))
                }
            }
        }
    }

    private func monitoringChanged() {
        statusItem.button?.alphaValue = settings.monitoring ? 1 : 0.45
        watcher.start()
    }

    private func openSettings() {
        panel.hide()
        settingsHost.show(title: "Recall Settings", size: NSSize(width: 440, height: 260),
                          SettingsView(settings: settings, store: store) { [weak self] s in
                              self?.hotkey.register(s) ?? false
                          })
    }

    private func openEditor(_ clip: Clip) {
        editHost.show(title: "Edit Clip", size: NSSize(width: 420, height: 260),
                      EditClipView(clip: clip,
                                   onSave: { [weak self] text in
                                       self?.store.updateText(clip.id, text)
                                       self?.editHost.close()
                                   },
                                   onCancel: { [weak self] in self?.editHost.close() }))
    }
}

private extension NSImage {
    /// Copy rotated about its centre (degrees, negative = clockwise), same size, keeps template flag.
    func rotated(by degrees: CGFloat) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            let t = NSAffineTransform()
            t.translateX(by: rect.midX, yBy: rect.midY)
            t.rotate(byDegrees: degrees)
            t.translateX(by: -rect.midX, yBy: -rect.midY)
            t.concat()
            self.draw(in: rect)
            return true
        }
        img.isTemplate = isTemplate
        return img
    }
}
