import Foundation
import Testing
@testable import RecallCore

@MainActor
struct SettingsTests {
    let defaults = UserDefaults(suiteName: "recall-test-\(UUID().uuidString)")!

    @Test func limitClamped() {
        let s = Settings(defaults: defaults)
        #expect(s.historyLimit == 200)
        s.historyLimit = 3
        #expect(s.historyLimit == 10)
        s.historyLimit = 9000
        #expect(s.historyLimit == 5000)
    }

    @Test func defaults_() {
        let s = Settings(defaults: defaults)
        #expect(s.interval == 0.5)
        #expect(s.monitoring)
        #expect(s.shortcut == .defaultValue)
        #expect(!s.firstLaunchDone)
    }

    @Test func persists() {
        let s = Settings(defaults: defaults)
        s.historyLimit = 300; s.interval = 2; s.monitoring = false
        s.shortcut = Shortcut(keyCode: 8, carbonModifiers: Shortcut.option | Shortcut.command)
        let again = Settings(defaults: defaults)
        #expect(again.historyLimit == 300 && again.interval == 2 && !again.monitoring)
        #expect(again.shortcut.keyCode == 8)
    }

    @Test func viewModeDefaultsToExpandedAndPersists() {
        let s = Settings(defaults: defaults)
        #expect(s.viewMode == .expanded)
        s.viewMode = .grid
        #expect(Settings(defaults: defaults).viewMode == .grid)
    }

    @Test func intervalMustBeAnOption() {
        let s = Settings(defaults: defaults)
        s.interval = 0.7
        #expect(s.interval == 0.5)
    }
}

struct ShortcutTests {
    @Test func needsModifier() {
        #expect(!Shortcut(keyCode: 9, carbonModifiers: Shortcut.shift).isValid)
        #expect(Shortcut(keyCode: 9, carbonModifiers: Shortcut.control).isValid)
        #expect(Shortcut.defaultValue.isValid)
    }

    @Test func display() {
        #expect(Shortcut.defaultValue.display == "⇧⌘V")
        #expect(Shortcut(keyCode: 8, carbonModifiers: Shortcut.option | Shortcut.command | Shortcut.control).display == "⌃⌥⌘C")
    }
}

struct ChangeTrackerTests {
    @Test func readsEachChangeOnce() {
        var t = ChangeTracker()
        let reads = [t.shouldRead(1), t.shouldRead(1), t.shouldRead(2)]
        #expect(reads == [true, false, true])
    }
}
