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

    public static func hidBusyFallback(deviceName: String) -> HIDDeviceStatus {
        HIDDeviceStatus(
            connected: true,
            name: "\(deviceName) (HID busy; fallback)",
            rawXYEnabled: false
        )
    }

    public static func openFailed(returnName: String) -> HIDDeviceStatus {
        HIDDeviceStatus(
            connected: false,
            name: "HID manager open failed \(returnName)",
            rawXYEnabled: false
        )
    }

    public static func noGestureCID(deviceName: String) -> HIDDeviceStatus {
        HIDDeviceStatus(
            connected: true,
            name: "\(deviceName) (no gesture CID)",
            rawXYEnabled: false
        )
    }

    public static func configured(deviceName: String, configuration: ReprogConfiguration) -> HIDDeviceStatus {
        HIDDeviceStatus(
            connected: true,
            name: "\(deviceName) CID 0x\(String(configuration.control.cid, radix: 16))",
            rawXYEnabled: configuration.rawXYEnabled,
            gestureConfigured: true
        )
    }

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
