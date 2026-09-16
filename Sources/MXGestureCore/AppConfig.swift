import Foundation

public struct AppConfig: Codable, Equatable {
    public var enabled: Bool
    public var mappings: [String: Shortcut]
    public var gesture: GestureRecognizer.Settings
    /// HID++ CIDs that should act as gesture triggers. Empty means auto-select
    /// the dedicated gesture button (0xC3 / 0xD7) when the device exposes one.
    /// Kept for older payloads; `buttonAssignments` is the source of truth once saved.
    public var gestureButtonCIDs: [UInt16]
    public var buttonAssignments: [String: ButtonAssignment]
    public var wheels: WheelSettings

    public init(
        enabled: Bool = true,
        mappings: [String: Shortcut] = Self.defaultMappings,
        gesture: GestureRecognizer.Settings = .init(),
        gestureButtonCIDs: [UInt16] = [],
        buttonAssignments: [String: ButtonAssignment] = [:],
        wheels: WheelSettings = WheelSettings()
    ) {
        self.enabled = enabled
        self.mappings = mappings
        self.gesture = gesture
        self.gestureButtonCIDs = gestureButtonCIDs
        self.buttonAssignments = buttonAssignments
        self.wheels = wheels
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case mappings
        case gesture
        case gestureButtonCIDs
        case buttonAssignments
        case wheels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        mappings = try container.decodeIfPresent([String: Shortcut].self, forKey: .mappings) ?? Self.defaultMappings
        gesture = try container.decodeIfPresent(GestureRecognizer.Settings.self, forKey: .gesture) ?? .init()
        gestureButtonCIDs = try container.decodeIfPresent([UInt16].self, forKey: .gestureButtonCIDs) ?? []
        buttonAssignments = try container.decodeIfPresent([String: ButtonAssignment].self, forKey: .buttonAssignments) ?? [:]
        wheels = try container.decodeIfPresent(WheelSettings.self, forKey: .wheels) ?? WheelSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(legacyMappings, forKey: .mappings)
        try container.encode(gesture, forKey: .gesture)
        try container.encode(legacyGestureButtonCIDs, forKey: .gestureButtonCIDs)
        try container.encode(resolvedAssignments, forKey: .buttonAssignments)
        try container.encode(wheels, forKey: .wheels)
    }

    public func shortcut(for event: GestureEvent, buttonID: String? = nil) -> Shortcut? {
        if let buttonID {
            let assigned = assignment(forButtonID: buttonID)
            guard assigned.action == .gesture else { return nil }
            if let mapped = assigned.mappings[event.rawValue] {
                return mapped
            }
            if assigned.mappings.isEmpty {
                return mappings[event.rawValue]
            }
            return nil
        }
        return mappings[event.rawValue]
    }

    public mutating func setShortcut(_ shortcut: Shortcut, for event: GestureEvent) {
        mappings[event.rawValue] = shortcut
    }

    public func assignment(forButtonID id: String) -> ButtonAssignment {
        if let stored = buttonAssignments[id] {
            return stored
        }
        guard let option = GestureButtonCatalog.option(id: id) else {
            return ButtonAssignment()
        }
        if GestureButtonCatalog.isSelected(option, cids: gestureButtonCIDs) {
            return .gesture(mappings: mappings.isEmpty ? Self.defaultMappings : mappings)
        }
        return ButtonAssignment()
    }

    public var resolvedAssignments: [String: ButtonAssignment] {
        Dictionary(
            uniqueKeysWithValues: GestureButtonCatalog.options.map { option in
                (option.id, assignment(forButtonID: option.id))
            }
        )
    }

    public var divertCIDs: [UInt16] {
        GestureButtonCatalog.options.flatMap { option in
            assignment(forButtonID: option.id).action == .default ? [] : option.cids
        }
    }

    public var gestureCIDs: [UInt16] {
        GestureButtonCatalog.options.flatMap { option in
            assignment(forButtonID: option.id).action == .gesture ? option.cids : []
        }
    }

    public var shortcutCIDs: [UInt16] {
        GestureButtonCatalog.options.flatMap { option in
            assignment(forButtonID: option.id).action == .shortcut ? option.cids : []
        }
    }

    public var gestureButtonIDs: [String] {
        GestureButtonCatalog.options
            .filter { assignment(forButtonID: $0.id).action == .gesture }
            .map(\.id)
    }

    public var primaryGestureButtonID: String {
        gestureButtonIDs.first ?? "gesture"
    }

    public func buttonID(forCID cid: UInt16) -> String? {
        GestureButtonCatalog.option(containingCID: cid)?.id
    }

    public func clickShortcut(forButtonID id: String) -> Shortcut? {
        let assigned = assignment(forButtonID: id)
        guard assigned.action == .shortcut else { return nil }
        return assigned.shortcut
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

    private var legacyGestureButtonCIDs: [UInt16] {
        let cids = gestureCIDs
        return cids.isEmpty ? gestureButtonCIDs : cids
    }

    private var legacyMappings: [String: Shortcut] {
        let assigned = assignment(forButtonID: primaryGestureButtonID)
        if assigned.action == .gesture, !assigned.mappings.isEmpty {
            return assigned.mappings
        }
        return mappings
    }

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
        if var gesture = migrated.buttonAssignments["gesture"], gesture.action == .gesture {
            if gesture.mappings[GestureEvent.left.rawValue] == legacyLeft,
               gesture.mappings[GestureEvent.right.rawValue] == legacyRight {
                gesture.mappings[GestureEvent.left.rawValue] = legacyRight
                gesture.mappings[GestureEvent.right.rawValue] = legacyLeft
                migrated.buttonAssignments["gesture"] = gesture
            }
        }
        migrated.save()
        return migrated
    }
}