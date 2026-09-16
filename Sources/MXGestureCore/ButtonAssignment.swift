import Foundation

public enum ButtonAction: String, Codable, CaseIterable, Equatable {
    case `default`
    case gesture
    case shortcut

    public var title: String {
        switch self {
        case .default: return "Default"
        case .gesture: return "Gesture"
        case .shortcut: return "Shortcut"
        }
    }
}

public struct ButtonAssignment: Codable, Equatable {
    public var action: ButtonAction
    public var shortcut: Shortcut
    public var mappings: [String: Shortcut]

    public init(
        action: ButtonAction = .default,
        shortcut: Shortcut = Shortcut(keys: []),
        mappings: [String: Shortcut] = [:]
    ) {
        self.action = action
        self.shortcut = shortcut
        self.mappings = mappings
    }

    public static func gesture(mappings: [String: Shortcut] = AppConfig.defaultMappings) -> ButtonAssignment {
        ButtonAssignment(action: .gesture, mappings: mappings)
    }
}

public struct WheelSettings: Codable, Equatable {
    public var invertMain: Bool
    public var invertThumb: Bool

    public init(invertMain: Bool = false, invertThumb: Bool = false) {
        self.invertMain = invertMain
        self.invertThumb = invertThumb
    }
}

public struct HIDDevicePolicy: Equatable {
    public var divertCIDs: [UInt16]
    public var gestureCIDs: [UInt16]
    public var autoSelectIfEmpty: Bool
    public var wheels: WheelSettings

    public init(
        divertCIDs: [UInt16] = [],
        gestureCIDs: [UInt16] = [],
        autoSelectIfEmpty: Bool = true,
        wheels: WheelSettings = WheelSettings()
    ) {
        self.divertCIDs = divertCIDs
        self.gestureCIDs = gestureCIDs
        self.autoSelectIfEmpty = autoSelectIfEmpty
        self.wheels = wheels
    }

    public static func from(_ config: AppConfig) -> HIDDevicePolicy {
        HIDDevicePolicy(
            divertCIDs: config.divertCIDs,
            gestureCIDs: config.gestureCIDs,
            autoSelectIfEmpty: false,
            wheels: config.wheels
        )
    }
}