import AppKit
import ApplicationServices
import RecallCore

@MainActor
final class Paster {
    enum Outcome { case pasted, copiedOnly, dataMissing }

    private var previousApp: NSRunningApplication?

    /// Call just before showing the panel so paste can return to that app.
    func rememberFrontApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = front }
    }

    var hasAccessibility: Bool { AXIsProcessTrusted() }

    func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Writes the clip to the clipboard, then sends ⌘V to the previous app when allowed.
    func paste(_ clip: Clip, plain: Bool, store: ClipStore, sendKeys: Bool = true) -> Outcome {
        guard let formats = store.data(for: clip.id) else {
            store.delete(clip.id)
            return .dataMissing
        }
        PasteboardWriter.write(formats: formats, plainOnly: plain, to: .general)
        store.touch(clip.id)
        guard sendKeys else { return .copiedOnly }
        previousApp?.activate()
        guard hasAccessibility else { return .copiedOnly }
        // Give the target app a moment to become key before the keystroke arrives.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let src = CGEventSource(stateID: .combinedSessionState)
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: down)
                e?.flags = .maskCommand
                e?.post(tap: .cghidEventTap)
            }
        }
        return .pasted
    }
}
