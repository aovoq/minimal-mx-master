import Foundation

public struct WheelApplyResult: Equatable {
    public var mainApplied: Bool
    public var thumbApplied: Bool
    public var mainReason: String?
    public var thumbReason: String?

    public init(
        mainApplied: Bool = false,
        thumbApplied: Bool = false,
        mainReason: String? = nil,
        thumbReason: String? = nil
    ) {
        self.mainApplied = mainApplied
        self.thumbApplied = thumbApplied
        self.mainReason = mainReason
        self.thumbReason = thumbReason
    }
}

public enum WheelControls {
    public static let hiresWheelFeatureID: UInt16 = 0x2121
    public static let thumbWheelFeatureID: UInt16 = 0x2150

    public static let invertFlag: UInt8 = 1 << 2

    public static func modeByte(current: UInt8, invert: Bool) -> UInt8 {
        invert ? (current | invertFlag) : (current & ~invertFlag)
    }
}

final class WheelFeatures {
    private let transport: HIDPPTransport

    init(transport: HIDPPTransport) {
        self.transport = transport
    }

    func apply(_ settings: WheelSettings) -> WheelApplyResult {
        var result = WheelApplyResult()
        result.mainApplied = applyMainWheel(invert: settings.invertMain, result: &result)
        result.thumbApplied = applyThumbWheel(invert: settings.invertThumb, result: &result)
        return result
    }

    private func applyMainWheel(invert: Bool, result: inout WheelApplyResult) -> Bool {
        guard let location = transport.firstFeature(WheelControls.hiresWheelFeatureID) else {
            result.mainReason = "HIRES_WHEEL 0x2121 not present"
            return false
        }

        let current = transport.request(
            deviceIndex: location.deviceIndex,
            featureIndex: location.featureIndex,
            function: 1,
            params: []
        )?.params.first ?? 0
        let mode = WheelControls.modeByte(current: current, invert: invert)
        guard transport.request(
            deviceIndex: location.deviceIndex,
            featureIndex: location.featureIndex,
            function: 2,
            params: [mode, 0, 0]
        ) != nil else {
            result.mainReason = "HIRES_WHEEL setWheelMode failed"
            return false
        }

        AppLog.hid.info("Set main wheel invert=\(invert)")
        return true
    }

    private func applyThumbWheel(invert: Bool, result: inout WheelApplyResult) -> Bool {
        guard let location = transport.firstFeature(WheelControls.thumbWheelFeatureID) else {
            result.thumbReason = "THUMB_WHEEL 0x2150 not present"
            return false
        }

        let status = transport.request(
            deviceIndex: location.deviceIndex,
            featureIndex: location.featureIndex,
            function: 1,
            params: []
        )
        let mode = status?.params.first ?? 0
        guard transport.request(
            deviceIndex: location.deviceIndex,
            featureIndex: location.featureIndex,
            function: 2,
            params: [mode, invert ? 1 : 0, 0]
        ) != nil else {
            result.thumbReason = "THUMB_WHEEL setThumbwheelReporting failed"
            return false
        }

        AppLog.hid.info("Set thumb wheel invert=\(invert) mode=\(mode)")
        return true
    }
}