import XCTest
@testable import MXGestureCore

final class ReprogControlsFeatureTests: XCTestCase {
    func testConfigureGestureEnablesRawXYReportingWhenAvailable() {
        let transport = FakeHIDPPTransport()
        transport.rawXYReportingSucceeds = true
        let feature = ReprogControlsFeature(transport: transport)

        let configuration = feature.configureGesture()

        XCTAssertEqual(configuration?.deviceIndex, 0xFF)
        XCTAssertEqual(configuration?.featureIndex, 0x05)
        XCTAssertEqual(configuration?.control.cid, 0x00C3)
        XCTAssertEqual(configuration?.rawXYEnabled, true)
        XCTAssertEqual(transport.reportingFlags, [ReprogControls.rawXYReportingFlags])
    }

    func testConfigureGestureFallsBackToDivertOnlyReporting() {
        let transport = FakeHIDPPTransport()
        transport.rawXYReportingSucceeds = false
        let feature = ReprogControlsFeature(transport: transport)

        let configuration = feature.configureGesture()

        XCTAssertEqual(configuration?.rawXYEnabled, false)
        XCTAssertEqual(transport.reportingFlags, [
            ReprogControls.rawXYReportingFlags,
            ReprogControls.divertOnlyReportingFlags
        ])
    }

    func testHandleEventEmitsButtonTransitionsAndRawXY() {
        let transport = FakeHIDPPTransport()
        transport.rawXYReportingSucceeds = true
        let feature = ReprogControlsFeature(transport: transport)
        _ = feature.configureGesture()

        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0xC3])),
            .buttonDown
        )
        XCTAssertNil(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0xC3]))
        )
        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x00])),
            .buttonUp
        )
        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 1, params: [0xFF, 0xFE, 0x00, 0x05])),
            .rawXY(dx: -2, dy: 5)
        )
    }
}

private final class FakeHIDPPTransport: HIDPPTransport {
    var rawXYReportingSucceeds = true
    var reportingFlags: [UInt8] = []

    func request(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> HIDPPMessage? {
        if deviceIndex == 0xFF,
           featureIndex == ReprogControls.rootFeatureIndex,
           function == 0 {
            return .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: [0x05])
        }

        if deviceIndex == 0xFF, featureIndex == 0x05, function == 0 {
            return .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: [1])
        }

        if deviceIndex == 0xFF, featureIndex == 0x05, function == 1 {
            return .init(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                function: function,
                params: [0x00, 0xC3, 0, 0, 0x20, 0, 0, 0, 0x01]
            )
        }

        if deviceIndex == 0xFF,
           featureIndex == 0x05,
           function == 3,
           params.count >= 3 {
            let flags = params[2]
            reportingFlags.append(flags)
            if flags == ReprogControls.rawXYReportingFlags, !rawXYReportingSucceeds {
                return nil
            }
            return .init(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: [])
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
