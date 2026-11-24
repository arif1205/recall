import AppKit
import Carbon
import RecallCore
import SwiftUI

/// Opens a plain titled window hosting a SwiftUI view, reusing it if already open.
@MainActor
final class WindowHost {
    private var window: NSWindow?

    func show<V: View>(title: String, size: NSSize, _ view: V) {
        window?.close()
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = title
        w.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: view)
        w.contentView = host
        w.setContentSize(host.fittingSize)
        w.center()
        window = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

/// Asks before a destructive action; returns true when the user confirms.
@MainActor
func confirm(_ title: String, _ message: String, button: String) -> Bool {
    let a = NSAlert()
    a.messageText = title
    a.informativeText = message
    a.alertStyle = .warning
    a.addButton(withTitle: button).hasDestructiveAction = true
    a.addButton(withTitle: "Cancel")
    NSApp.activate()
    return a.runModal() == .alertFirstButtonReturn
}

struct EditClipView: View {
    let clip: Clip
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @State private var text: String

    init(clip: Clip, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.clip = clip
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: clip.plainText ?? clip.preview)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $text).font(.system(.body, design: .monospaced))
            if clip.kind == .rich {
                Text("Saving turns this rich text into plain text.").font(.caption).foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save") { onSave(text) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 420, height: 260)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: RecallCore.Settings
    @ObservedObject var store: ClipStore
    /// Returns false when the shortcut is taken by another app.
    let applyShortcut: (Shortcut) -> Bool

    @State private var recording = false
    @State private var warning = ""
    @State private var limitText = ""
    @State private var loginOn = LoginItem.isEnabled
    @State private var monitor: Any?

    var body: some View {
        Form {
            LabeledContent("Shortcut") {
                HStack {
                    Button(recording ? "Press new keys…" : settings.shortcut.display) { startRecording() }
                        .frame(minWidth: 110)
                    Button("Reset to ⌘⇧V") { set(.defaultValue) }
                }
            }
            if !warning.isEmpty {
                Text(warning).font(.caption).foregroundStyle(.orange)
            }
            LabeledContent("History") {
                HStack {
                    TextField("", text: $limitText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .onSubmit(applyLimit)
                        .accessibilityLabel("History limit")
                    Stepper("", value: Binding(get: { Int(limitText) ?? settings.historyLimit },
                                               set: { limitText = "\($0)"; applyLimit() }),
                            in: 10...5000, step: 10)
                        .labelsHidden()
                    Text("clips (10–5000, pinned not counted)").foregroundStyle(.secondary).font(.caption)
                }
            }
            Toggle("Start at Login", isOn: Binding(get: { loginOn },
                                                   set: { LoginItem.set($0); loginOn = LoginItem.isEnabled }))
            Button("Clear All History…", role: .destructive) { clearAll() }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onAppear { limitText = "\(settings.historyLimit)"; loginOn = LoginItem.isEnabled }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        warning = ""
        recording = true
        stopRecording(keepFlag: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            let f = e.modifierFlags
            var mods: UInt32 = 0
            if f.contains(.command) { mods |= Shortcut.command }
            if f.contains(.shift) { mods |= Shortcut.shift }
            if f.contains(.option) { mods |= Shortcut.option }
            if f.contains(.control) { mods |= Shortcut.control }
            set(Shortcut(keyCode: UInt32(e.keyCode), carbonModifiers: mods))
            stopRecording()
            return nil
        }
    }

    private func stopRecording(keepFlag: Bool = false) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if !keepFlag { recording = false }
    }

    private func set(_ s: Shortcut) {
        guard s.isValid else {
            warning = "Needs ⌘, ⌃ or ⌥ — a plain key would block typing. Kept \(settings.shortcut.display)."
            return
        }
        if applyShortcut(s) {
            settings.shortcut = s
            warning = ""
        } else {
            warning = "\(s.display) is already used by another app. Kept \(settings.shortcut.display)."
        }
    }

    private func applyLimit() {
        let v = min(5000, max(10, Int(limitText) ?? settings.historyLimit))
        let over = store.overflow(ifLimit: v)
        if over > 0, !confirm("Lower the history limit?",
                              "This will delete \(over) older clip\(over == 1 ? "" : "s"). Pinned clips are kept.",
                              button: "Delete \(over)") {
            limitText = "\(settings.historyLimit)"
            return
        }
        settings.historyLimit = v
        store.historyLimit = v
        limitText = "\(v)"
    }

    private func clearAll() {
        let n = store.clips.filter { !$0.pinned }.count
        if confirm("Clear all history?", "Deletes \(n) clip\(n == 1 ? "" : "s"). Pinned clips are kept. This can't be undone.",
                   button: "Clear All") {
            store.clearHistory()
        }
    }
}
