import Foundation

/// Centralized access to persisted user preferences backed by UserDefaults.
///
/// Each property reads from / writes to UserDefaults with a "SlapMyMac." prefix.
/// Use this as a value type to snapshot or pass preferences around; for live
/// two-way binding the AppState `didSet` observers keep UserDefaults in sync.
struct Preferences {

    // MARK: - Keys

    private enum Key {
        static let selectedPackId = "SlapMyMac.selectedPackId"
        static let volume         = "SlapMyMac.volume"
        static let sensitivity    = "SlapMyMac.sensitivity"
        static let isEnabled      = "SlapMyMac.isEnabled"
        static let launchAtLogin  = "SlapMyMac.launchAtLogin"
        static let totalSlaps     = "SlapMyMac.totalSlaps"
        static let cooldown       = "SlapMyMac.cooldown"
        static let showInDock     = "SlapMyMac.showInDock"
        static let dynamicMode    = "SlapMyMac.dynamicMode"
    }

    // MARK: - Defaults

    private static let defaults = UserDefaults.standard

    // MARK: - Properties

    var selectedPackId: String {
        get { Self.defaults.string(forKey: Key.selectedPackId) ?? "Pain" }
        set { Self.defaults.set(newValue, forKey: Key.selectedPackId) }
    }

    var volume: Double {
        get {
            let stored = Self.defaults.object(forKey: Key.volume)
            return (stored as? Double) ?? 0.7
        }
        set { Self.defaults.set(newValue, forKey: Key.volume) }
    }

    var sensitivity: Double {
        get {
            let stored = Self.defaults.object(forKey: Key.sensitivity)
            return (stored as? Double) ?? 0.5
        }
        set { Self.defaults.set(newValue, forKey: Key.sensitivity) }
    }

    var isEnabled: Bool {
        get { Self.defaults.bool(forKey: Key.isEnabled) }
        set { Self.defaults.set(newValue, forKey: Key.isEnabled) }
    }

    var launchAtLogin: Bool {
        get { Self.defaults.bool(forKey: Key.launchAtLogin) }
        set { Self.defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    var totalSlaps: Int {
        get { Self.defaults.integer(forKey: Key.totalSlaps) }
        set { Self.defaults.set(newValue, forKey: Key.totalSlaps) }
    }

    var cooldown: Double {
        get {
            let stored = Self.defaults.object(forKey: Key.cooldown)
            return (stored as? Double) ?? 0.3
        }
        set { Self.defaults.set(newValue, forKey: Key.cooldown) }
    }

    var showInDock: Bool {
        get { Self.defaults.bool(forKey: Key.showInDock) }
        set { Self.defaults.set(newValue, forKey: Key.showInDock) }
    }

    var dynamicMode: Bool {
        get {
            let stored = Self.defaults.object(forKey: Key.dynamicMode)
            return (stored as? Bool) ?? true
        }
        set { Self.defaults.set(newValue, forKey: Key.dynamicMode) }
    }

    // MARK: - Bulk Registration

    /// Registers default values so first-launch reads return sensible results.
    static func registerDefaults() {
        defaults.register(defaults: [
            Key.selectedPackId: "Pain",
            Key.volume: 0.7,
            Key.sensitivity: 0.5,
            Key.isEnabled: true,
            Key.launchAtLogin: false,
            Key.totalSlaps: 0,
            Key.cooldown: 0.3,
            Key.showInDock: false,
            Key.dynamicMode: true,
        ])
    }
}
