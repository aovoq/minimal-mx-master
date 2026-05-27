import Foundation

public struct AppConfig: Codable, Equatable {
    public var enabled: Bool
    public var mappings: [String: Shortcut]
    public var gesture: GestureRecognizer.Settings

    public init(
        enabled: Bool = true,
        mappings: [String: Shortcut] = Self.defaultMappings,
        gesture: GestureRecognizer.Settings = .init()
    ) {
        self.enabled = enabled
        self.mappings = mappings
        self.gesture = gesture
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
