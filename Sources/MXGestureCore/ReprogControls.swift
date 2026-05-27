import Foundation

public struct ReprogControl: Equatable {
    public var cid: UInt16
    public var taskID: UInt16
    public var flags: UInt8
    public var additionalFlags: UInt8

    public var isVirtual: Bool { flags & 0x80 != 0 }
    public var isDivertable: Bool { flags & 0x20 != 0 }
    public var hasRawXY: Bool { additionalFlags & 0x01 != 0 }
    public var isGestureCandidate: Bool {
        cid == 0x00C3 || cid == 0x00D7 || (isDivertable && (hasRawXY || isVirtual))
    }
}

public struct ReprogConfiguration: Equatable {
    public var deviceIndex: UInt8
    public var featureIndex: UInt8
    public var control: ReprogControl
    public var rawXYEnabled: Bool
}

public enum ReprogControls {
    public static let featureID: UInt16 = 0x1B04
    public static let rootFeatureIndex: UInt8 = 0x00

    public static let preferredGestureCIDs: [UInt16] = [
        0x00C3,
        0x00D7
    ]

    public static let rawXYReportingFlags: UInt8 = 0x33
    public static let divertOnlyReportingFlags: UInt8 = 0x03
    public static let clearReportingFlags: UInt8 = 0x22

    public static func chooseGestureControl(from controls: [ReprogControl]) -> ReprogControl? {
        for cid in preferredGestureCIDs {
            if let match = controls.first(where: { $0.cid == cid && $0.isDivertable }) {
                return match
            }
        }
        return controls.first(where: { $0.isGestureCandidate })
    }

    public static func pressedCIDs(from eventParams: [UInt8]) -> Set<UInt16> {
        var output = Set<UInt16>()
        var index = 0
        while index + 1 < eventParams.count {
            let cid = UInt16(eventParams[index]) << 8 | UInt16(eventParams[index + 1])
            if cid != 0 { output.insert(cid) }
            index += 2
        }
        return output
    }

    public static func rawXY(from eventParams: [UInt8]) -> (dx: Int, dy: Int)? {
        guard eventParams.count >= 4 else { return nil }
        return (
            dx: Int(Int16(bitPattern: UInt16(eventParams[0]) << 8 | UInt16(eventParams[1]))),
            dy: Int(Int16(bitPattern: UInt16(eventParams[2]) << 8 | UInt16(eventParams[3])))
        )
    }
}
