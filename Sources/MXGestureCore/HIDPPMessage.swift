import Foundation

public struct HIDPPMessage: Equatable {
    public static let longReportID: UInt8 = 0x11
    public static let maxLongReportLength = 20
    public static let softwareID: UInt8 = 0x0B

    public var reportID: UInt8
    public var deviceIndex: UInt8
    public var featureIndex: UInt8
    public var function: UInt8
    public var softwareID: UInt8
    public var params: [UInt8]

    public init(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) {
        self.reportID = Self.longReportID
        self.deviceIndex = deviceIndex
        self.featureIndex = featureIndex
        self.function = function
        self.softwareID = Self.softwareID
        self.params = params
    }

    public init?(reportID: UInt8, bytes: [UInt8]) {
        var normalized = bytes
        if normalized.first != reportID {
            normalized.insert(reportID, at: 0)
        }
        guard normalized.count >= 4, normalized[0] == Self.longReportID else { return nil }

        self.reportID = normalized[0]
        self.deviceIndex = normalized[1]
        self.featureIndex = normalized[2]
        self.function = normalized[3] >> 4
        self.softwareID = normalized[3] & 0x0F
        self.params = Array(normalized.dropFirst(4))
    }

    public var bytes: [UInt8] {
        var output = [
            reportID,
            deviceIndex,
            featureIndex,
            (function << 4) | softwareID
        ]
        output.append(contentsOf: params.prefix(Self.maxLongReportLength - output.count))
        while output.count < Self.maxLongReportLength {
            output.append(0)
        }
        return output
    }

    var requestKey: HIDPPRequestKey {
        HIDPPRequestKey(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function)
    }

    public func matches(deviceIndex: UInt8, featureIndex: UInt8, function: UInt8) -> Bool {
        self.deviceIndex == deviceIndex &&
            self.featureIndex == featureIndex &&
            self.function == function
    }
}
