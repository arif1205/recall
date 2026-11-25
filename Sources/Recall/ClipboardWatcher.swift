import AppKit
import RecallCore

/// Polls the pasteboard: macOS has no clipboard-change notification.
@MainActor
final class ClipboardWatcher {
    private let store: ClipStore
    private let settings: Settings
    private let pasteboard: NSPasteboard
    private var tracker = ChangeTracker()
    private var timer: Timer?
    var onSaved: () -> Void = {}

    init(store: ClipStore, settings: Settings, pasteboard: NSPasteboard = .general) {
        self.store = store
        self.settings = settings
        self.pasteboard = pasteboard
    }

    /// (Re)starts with the current interval; call again after the interval setting changes.
    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.interval, repeats: true) { _ in
            MainActor.assumeIsolated { self.poll() }
        }
        timer?.tolerance = settings.interval / 5
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Recall's own clipboard writes aren't new copies; re-reading them rewrote the clip's label and source app.
    func skipCurrentChange() { _ = tracker.shouldRead(pasteboard.changeCount) }

    func poll() {
        guard tracker.shouldRead(pasteboard.changeCount), settings.monitoring else { return }
        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if case .clip(let draft) = PasteboardReader.read(pasteboard, sourceBundleID: source) {
            store.add(draft)
            onSaved()
        }
    }
}
