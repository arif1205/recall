/// A global shortcut as Carbon key code + Carbon modifier mask.
public struct Shortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    // Carbon's cmdKey/shiftKey/optionKey/controlKey, so RecallCore needn't import Carbon.
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12

    public static let defaultValue = Shortcut(keyCode: 9, carbonModifiers: command | shift)

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// Without ⌘, ⌃ or ⌥ the shortcut would swallow normal typing (#29).
    public var isValid: Bool { carbonModifiers & (Self.command | Self.control | Self.option) != 0 }

    public var display: String {
        var s = ""
        if carbonModifiers & Self.control != 0 { s += "⌃" }
        if carbonModifiers & Self.option != 0 { s += "⌥" }
        if carbonModifiers & Self.shift != 0 { s += "⇧" }
        if carbonModifiers & Self.command != 0 { s += "⌘" }
        return s + (Self.keyNames[keyCode] ?? "Key \(keyCode)")
    }

    // US-layout virtual key codes (kVK_ANSI_*).
    static let keyNames: [UInt32: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K", 37: "L",
        46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W",
        7: "X", 16: "Y", 6: "Z", 29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋", 50: "`", 27: "-", 24: "=",
        33: "[", 30: "]", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 42: "\\",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

/// Remembers the last pasteboard changeCount so each copy is read once.
public struct ChangeTracker: Sendable {
    private var last: Int?
    public init() {}
    public mutating func shouldRead(_ count: Int) -> Bool {
        guard count != last else { return false }
        last = count
        return true
    }
}
