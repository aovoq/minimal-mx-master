import XCTest
@testable import MXGestureCore

final class WheelFeaturesTests: XCTestCase {
    func testApplyInvertsMainWheelWhilePreservingExistingModeBits() {
        let transport = FakeWheelTransport()
        transport.mainMode = 0b0000_0010
        let features = WheelFeatures(transport: transport)

        let result = features.apply(WheelSettings(invertMain: true, invertThumb: false))

        XCTAssertTrue(result.mainApplied)
        XCTAssertTrue(result.thumbApplied)
        XCTAssertEqual(transport.mainSetMode, [WheelControls.invertFlag | 0b0000_0010, 0, 0])
        XCTAssertEqual(transport.thumbSet, [0, 0, 0])
    }

    func testApplyInvertsThumbWheelWithoutDivertingIt() {
        let transport = FakeWheelTransport()
        transport.thumbMode = 0
        let features = WheelFeatures(transport: transport)

        let result = features.apply(WheelSettings(invertMain: false, invertThumb: true))

        XCTAssertTrue(result.mainApplied)
        XCTAssertTrue(result.thumbApplied)
        XCTAssertEqual(transport.thumbSet, [0, 1, 0])
        XCTAssertEqual(transport.mainSetMode?.first, 0)
    }

    func testApplyRecordsMissingWheelFeatures() {
        let transport = FakeWheelTransport(hasMain: false, hasThumb: false)
        let features = WheelFeatures(transport: transport)

        let result = features.apply(WheelSettings(invertMain: true, invertThumb: true))

        XCTAssertFalse(result.mainApplied)
        XCTAssertFalse(result.thumbApplied)
        XCTAssertEqual(result.mainReason, "HIRES_WHEEL 0x2121 not present")
        XCTAssertEqual(result.thumbReason, "THUMB_WHEEL 0x2150 not present")
    }
}

private final class FakeWheelTransport: HIDPPTransport {
    var hasMain: Bool
    var hasThumb: Bool
    var mainMode: UInt8 = 0
    var thumbMode: UInt8 = 0
    var mainSetMode: [UInt8]?
    var thumbSet: [UInt8]?

    init(hasMain: Bool = true, hasThumb: Bool = true) {
        self.hasMain = hasMain
        self.hasThumb = hasThumb
    }

    func request(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> HIDPPMessage? {
        if deviceIndex == 0xFF, featureIndex == ReprogControls.rootFeatureIndex, function == 0 {
            let id = UInt16(params[0]) << 8 | UInt16(params[1])
            if id == WheelControls.hiresWheelFeatureID {
                return hasMain ? .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: [0x06]) : nil
            }
            if id == WheelControls.thumbWheelFeatureID {
                return hasThumb ? .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: [0x07]) : nil
            }
            return nil
        }

        if deviceIndex == 0xFF, featureIndex == 0x06 {
            if function == 1 {
                return .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: [mainMode])
            }
            if function == 2 {
                mainSetMode = params
                return .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: params)
            }
        }

        if deviceIndex == 0xFF, featureIndex == 0x07 {
            if function == 1 {
                return .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: [thumbMode, 0])
            }
            if function == 2 {
                thumbSet = params
                return .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: params)
            }
        }

        return nil
    }

    func send(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> Bool {
        true
    }
}