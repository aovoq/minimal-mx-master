import Foundation

public struct HIDDeviceStatus: Equatable {
    public var connected: Bool
    public var name: String
    public var rawXYEnabled: Bool
    public var gestureConfigured: Bool

    public static let notConnected = HIDDeviceStatus(
        connected: false,
        name: "Not connected",
        rawXYEnabled: false
    )

    public init(
        connected: Bool,
        name: String,
        rawXYEnabled: Bool,
        gestureConfigured: Bool = false
    ) {
        self.connected = connected
        self.name = name
        self.rawXYEnabled = rawXYEnabled
        self.gestureConfigured = gestureConfigured
    }
}
