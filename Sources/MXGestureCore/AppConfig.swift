import Foundation

public struct AppConfig: Codable, Equatable {
    public var enabled: Bool
    public var mappings: [String: Shortcut]
    public var gesture: GestureRecognizer.Settings
    /// HID++ CIDs that should act as gesture triggers. Empty means auto-select
    /// the dedicated gesture button (0xC3 / 0xD7) when the device exposes one.
    public var gestureButtonCIDs: [UInt16]

    public init(
        enabled: Bool = true,
        mappings: [String: Shortcut] = Self.defaultMappings,
        gesture: GestureRecognizer.Settings = .init(),
        gestureButtonCIDs: [UInt16] = []
    ) {
        self.enabled = enabled
        self.mappings = mappings
        self.gesture = gesture
        self.gestureButtonCIDs = gestureButtonCIDs
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case mappings
        case gesture
        case gestureButtonCIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        mappings = try container.decodeIfPresent([String: Shortcut].self, forKey: .mappings) ?? Self.defaultMappings
        gesture = try container.decodeIfPresent(GestureRecognizer.Settings.self, forKey: .gesture) ?? .init()
        gestureButtonCIDs = try container.decodeIfPresent([UInt16].self, forKey: .gestureButtonCIDs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(mappings, forKey: .mappings)
        try container.encode(gesture, forKey: .gesture)
        try container.encode(gestureButtonCIDs, forKey: .gestureButtonCIDs)
    }

    public func shortcut(for event: GestureEvent) -> Shortcut? {
        mappings[event.rawValue]
    }

    public mutating func setShortcut(_ shortcut: Shortcut, for event: GestureEvent) {
        mappings[event.rawValue] = shortcut
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    public static func load() -> AppConfig {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else {
            let defaults = AppConfig()
            defaults.save()
            return defaults
        }
        return config.migratingLegacyDefaults()
    }

    public static let defaultMappings: [String: Shortcut] = [
        GestureEvent.click.rawValue: Shortcut(keys: ["ctrl", "up"]),
        GestureEvent.up.rawValue: Shortcut(keys: ["cmd", "tab"]),
        GestureEvent.down.rawValue: Shortcut(keys: ["ctrl", "down"]),
        GestureEvent.left.rawValue: Shortcut(keys: ["ctrl", "right"]),
        GestureEvent.right.rawValue: Shortcut(keys: ["ctrl", "left"])
    ]

    private static let defaultsKey = "MXGestureBar.config.v1"

    private func migratingLegacyDefaults() -> AppConfig {
        let legacyLeft = Shortcut(keys: ["ctrl", "left"])
        let legacyRight = Shortcut(keys: ["ctrl", "right"])
        guard
            mappings[GestureEvent.left.rawValue] == legacyLeft,
            mappings[GestureEvent.right.rawValue] == legacyRight
        else { return self }

        var migrated = self
        migrated.mappings[GestureEvent.left.rawValue] = legacyRight
        migrated.mappings[GestureEvent.right.rawValue] = legacyLeft
        migrated.save()
        return migrated
    }
}
