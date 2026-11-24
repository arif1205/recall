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

        hotkey.onPress = { [weak self] in self?.panel.toggle() }
        _ = hotkey.register(settings.shortcut)

        if !settings.firstLaunchDone {
            LoginItem.set(true) // #11: on by default
            paster.requestAccessibility()
            settings.firstLaunchDone = true
        }
    }

    @objc private func iconClicked() { panel.toggle() }

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
