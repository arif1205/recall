import Foundation

@MainActor
public final class Settings: ObservableObject {
    public static let intervals: [Double] = [0.25, 0.5, 1, 2]
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var historyLimit: Int {
        get { (defaults.object(forKey: "recall.historyLimit") as? Int) ?? 200 }
        set { objectWillChange.send(); defaults.set(min(5000, max(10, newValue)), forKey: "recall.historyLimit") }
    }

    public var interval: Double {
        get { (defaults.object(forKey: "recall.interval") as? Double) ?? 0.5 }
        set {
            objectWillChange.send()
            defaults.set(Self.intervals.contains(newValue) ? newValue : 0.5, forKey: "recall.interval")
        }
    }

    public var monitoring: Bool {
        get { (defaults.object(forKey: "recall.monitoring") as? Bool) ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "recall.monitoring") }
    }

    public var shortcut: Shortcut {
        get {
            defaults.data(forKey: "recall.shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
                ?? .defaultValue
        }
        set { objectWillChange.send(); defaults.set(try? JSONEncoder().encode(newValue), forKey: "recall.shortcut") }
    }

    public var firstLaunchDone: Bool {
        get { defaults.bool(forKey: "recall.firstLaunchDone") }
        set { defaults.set(newValue, forKey: "recall.firstLaunchDone") }
    }
}
