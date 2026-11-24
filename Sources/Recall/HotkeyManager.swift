import Carbon
import RecallCore

/// Global shortcut via Carbon, which works without Accessibility permission.
@MainActor
final class HotkeyManager {
    var onPress: () -> Void = {}
    private var ref: EventHotKeyRef?
    private var current: Shortcut?
    private var handler: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(ctx!).takeUnretainedValue()
            MainActor.assumeIsolated { mgr.onPress() }
            return noErr
        }, 1, &spec, me, &handler)
    }

    /// Returns false when another app already owns the shortcut; the previous one stays active.
    func register(_ s: Shortcut) -> Bool {
        // Unregister first: re-registering our own current shortcut would otherwise report "taken".
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        if install(s) { current = s; return true }
        if let current { _ = install(current) }
        return false
    }

    private func install(_ s: Shortcut) -> Bool {
        var newRef: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x5243_4C4C), id: 1) // "RCLL"
        guard RegisterEventHotKey(s.keyCode, s.carbonModifiers, id, GetApplicationEventTarget(), 0, &newRef) == noErr
        else { return false }
        ref = newRef
        return true
    }
}
