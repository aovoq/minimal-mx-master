import Foundation

public struct HIDDeviceStatus: Equatable {
    public var connected: Bool
    public var name: String
    public var rawXYEnabled: Bool
    public var gestureConfigured: Bool
    public var eventTapFallback: Bool

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
        var name = "\(deviceName) CID \(cidList(configuration.controls.map(\.cid)))"
        if !configuration.skipped.isEmpty {
            let skipped = configuration.skipped
                .map { "0x\(String($0.cid, radix: 16)) \($0.reason)" }
                .joined(separator: ", ")
            name += "; skipped \(skipped)"
        }
        return HIDDeviceStatus(
            connected: true,
            name: name,
            rawXYEnabled: configuration.rawXYEnabled,
            gestureConfigured: true
        )
    }

    public static func nativeButtons(deviceName: String) -> HIDDeviceStatus {
        HIDDeviceStatus(
            connected: true,
            name: deviceName,
            rawXYEnabled: false,
            gestureConfigured: false,
            eventTapFallback: false
        )
    }

    public init(
        connected: Bool,
        name: String,
        rawXYEnabled: Bool,
        gestureConfigured: Bool = false,
        eventTapFallback: Bool? = nil
    ) {
        self.connected = connected
        self.name = name
        self.rawXYEnabled = rawXYEnabled
        self.gestureConfigured = gestureConfigured
        self.eventTapFallback = eventTapFallback ?? (connected && !gestureConfigured)
    }

    private static func cidList(_ cids: [UInt16]) -> String {
        cids.map { "0x\(String($0, radix: 16))" }.joined(separator: ", ")
    }
}
