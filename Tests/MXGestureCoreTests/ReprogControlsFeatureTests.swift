import XCTest
@testable import MXGestureCore

final class ReprogControlsFeatureTests: XCTestCase {
    func testConfigureGestureEnablesRawXYReportingWhenAvailable() {
        let transport = FakeHIDPPTransport()
        let feature = ReprogControlsFeature(transport: transport)

        let configuration = feature.configureGesture()

        XCTAssertEqual(configuration?.deviceIndex, 0xFF)
        XCTAssertEqual(configuration?.featureIndex, 0x05)
        XCTAssertEqual(configuration?.controls.map(\.cid), [0x00C3])
        XCTAssertEqual(configuration?.rawXYEnabled, true)
        XCTAssertEqual(transport.reporting.map(\.cid), [0x00C3])
        XCTAssertEqual(transport.reporting.map(\.flags), [ReprogControls.rawXYReportingFlags])
    }

    func testConfigureGestureFallsBackToDivertOnlyReporting() {
        let transport = FakeHIDPPTransport()
        transport.rawXYReportingSucceeds = false
        let feature = ReprogControlsFeature(transport: transport)

        let configuration = feature.configureGesture()

        XCTAssertEqual(configuration?.rawXYEnabled, false)
        XCTAssertEqual(transport.reporting.map(\.cid), [0x00C3, 0x00C3])
        XCTAssertEqual(transport.reporting.map(\.flags), [
            ReprogControls.rawXYReportingFlags,
            ReprogControls.divertOnlyReportingFlags
        ])
    }

    func testConfigureGestureDivertsAdditionalSelectedButtons() {
        let transport = FakeHIDPPTransport(controls: [
            .gesture,
            .back
        ])
        let feature = ReprogControlsFeature(transport: transport)

        let configuration = feature.configureGesture(selectedCIDs: [0x00C3, 0x0053])

        XCTAssertEqual(configuration?.controls.map(\.cid), [0x00C3, 0x0053])
        XCTAssertEqual(configuration?.rawXYEnabled, true)
        XCTAssertEqual(transport.reporting.map(\.cid), [0x00C3, 0x0053])
        XCTAssertEqual(transport.reporting.map(\.flags), [
            ReprogControls.rawXYReportingFlags,
            ReprogControls.divertOnlyReportingFlags
        ])
    }

    func testConfigureGestureCanUseBackButtonWithoutDedicatedGestureCID() {
        let transport = FakeHIDPPTransport(controls: [.back])
        let feature = ReprogControlsFeature(transport: transport)

        let configuration = feature.configureGesture(selectedCIDs: [0x0053])

        XCTAssertEqual(configuration?.controls.map(\.cid), [0x0053])
        XCTAssertEqual(configuration?.rawXYEnabled, false)
        XCTAssertEqual(transport.reporting.map(\.cid), [0x0053])
        XCTAssertEqual(transport.reporting.map(\.flags), [ReprogControls.divertOnlyReportingFlags])
    }

    func testHandleEventTreatsAnySelectedButtonAsTheGestureTrigger() {
        let transport = FakeHIDPPTransport(controls: [.gesture, .back])
        let feature = ReprogControlsFeature(transport: transport)
        _ = feature.configureGesture(selectedCIDs: [0x00C3, 0x0053])

        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x53])),
            .buttonDown(cid: 0x0053)
        )
        XCTAssertNil(
            feature.handleEvent(.init(
                deviceIndex: 0xFF,
                featureIndex: 0x05,
                function: 0,
                params: [0x00, 0xC3, 0x00, 0x53]
            ))
        )
        XCTAssertNil(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0xC3]))
        )
        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x00])),
            .buttonUp(cid: 0x0053)
        )
    }

    func testHandleEventEmitsButtonTransitionsAndRawXY() {
        let transport = FakeHIDPPTransport()
        let feature = ReprogControlsFeature(transport: transport)
        _ = feature.configureGesture()

        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0xC3])),
            .buttonDown(cid: 0x00C3)
        )
        XCTAssertNil(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0xC3]))
        )
        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x00])),
            .buttonUp(cid: 0x00C3)
        )
        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 1, params: [0xFF, 0xFE, 0x00, 0x05])),
            .rawXY(dx: -2, dy: 5)
        )
    }

    func testRestoreDefaultReportingClearsEveryConfiguredCID() {
        let transport = FakeHIDPPTransport(controls: [.gesture, .back])
        let feature = ReprogControlsFeature(transport: transport)
        _ = feature.configureGesture(selectedCIDs: [0x00C3, 0x0053])

        feature.restoreDefaultReporting()

        XCTAssertEqual(transport.clearedCIDs, [0x00C3, 0x0053])
    }

    func testHandleEventIgnoresUnselectedButtons() {
        let transport = FakeHIDPPTransport(controls: [.gesture, .back])
        let feature = ReprogControlsFeature(transport: transport)
        _ = feature.configureGesture(selectedCIDs: [0x00C3])

        XCTAssertNil(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x53]))
        )
    }

    func testConfigureGestureDivertsLeftWhenDivertable() {
        let transport = FakeHIDPPTransport(controls: [.left, .gesture])
        let feature = ReprogControlsFeature(transport: transport)

        let configuration = feature.configureGesture(
            selectedCIDs: [0x0050, 0x00C3],
            autoSelectIfEmpty: false
        )

        XCTAssertEqual(configuration?.controls.map(\.cid), [0x0050, 0x00C3])
        XCTAssertEqual(configuration?.skipped, [])
    }

    func testConfigureGestureRecordsNonDivertableLeftInsteadOfSilentSkip() {
        let transport = FakeHIDPPTransport(controls: [.leftFixed, .back])
        let feature = ReprogControlsFeature(transport: transport)

        let configuration = feature.configureGesture(
            selectedCIDs: [0x0050, 0x0053],
            autoSelectIfEmpty: false
        )

        XCTAssertEqual(configuration?.controls.map(\.cid), [0x0053])
        XCTAssertEqual(configuration?.skipped, [SkippedControl(cid: 0x0050, reason: "not divertable")])
    }

    func testHandleEventKeepsHoldCIDFromTheButtonThatStartedIt() {
        let transport = FakeHIDPPTransport(controls: [.gesture, .back])
        let feature = ReprogControlsFeature(transport: transport)
        _ = feature.configureGesture(
            selectedCIDs: [0x00C3, 0x0053],
            gestureCIDs: [0x00C3, 0x0053],
            autoSelectIfEmpty: false
        )

        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x53])),
            .buttonDown(cid: 0x0053)
        )
        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x00])),
            .buttonUp(cid: 0x0053)
        )
        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0xC3])),
            .buttonDown(cid: 0x00C3)
        )
    }

    func testShortcutButtonsEmitPressWithoutHold() {
        let transport = FakeHIDPPTransport(controls: [.back])
        let feature = ReprogControlsFeature(transport: transport)
        _ = feature.configureGesture(
            selectedCIDs: [0x0053],
            gestureCIDs: [],
            autoSelectIfEmpty: false
        )

        XCTAssertEqual(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x53])),
            .buttonDown(cid: 0x0053)
        )
        XCTAssertNil(
            feature.handleEvent(.init(deviceIndex: 0xFF, featureIndex: 0x05, function: 0, params: [0x00, 0x00]))
        )
    }
}

private struct FakeReprogControl {
    var control: ReprogControl

    static let gesture = FakeReprogControl(
        control: ReprogControl(cid: 0x00C3, taskID: 0, flags: 0x20, additionalFlags: 0x01)
    )
    static let back = FakeReprogControl(
        control: ReprogControl(cid: 0x0053, taskID: 0, flags: 0x20, additionalFlags: 0)
    )
    static let left = FakeReprogControl(
        control: ReprogControl(cid: 0x0050, taskID: 0, flags: 0x20, additionalFlags: 0)
    )
    static let leftFixed = FakeReprogControl(
        control: ReprogControl(cid: 0x0050, taskID: 0, flags: 0x00, additionalFlags: 0)
    )
}

private final class FakeHIDPPTransport: HIDPPTransport {
    var rawXYReportingSucceeds = true
    var reporting: [(cid: UInt16, flags: UInt8)] = []
    var clearedCIDs: [UInt16] = []
    private let controls: [ReprogControl]

    init(controls: [FakeReprogControl] = [.gesture]) {
        self.controls = controls.map(\.control)
    }

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
            return .init(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                function: function,
                params: [UInt8(controls.count)]
            )
        }

        if deviceIndex == 0xFF, featureIndex == 0x05, function == 1 {
            let index = Int(params.first ?? 0)
            guard controls.indices.contains(index) else { return nil }
            let control = controls[index]
            return .init(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                function: function,
                params: [
                    UInt8(control.cid >> 8),
                    UInt8(control.cid & 0xFF),
                    UInt8(control.taskID >> 8),
                    UInt8(control.taskID & 0xFF),
                    control.flags,
                    0, 0, 0,
                    control.additionalFlags
                ]
            )
        }

        if deviceIndex == 0xFF,
           featureIndex == 0x05,
           function == 3,
           params.count >= 3 {
            let cid = UInt16(params[0]) << 8 | UInt16(params[1])
            let flags = params[2]
            reporting.append((cid: cid, flags: flags))
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
        if function == 3, params.count >= 2 {
            clearedCIDs.append(UInt16(params[0]) << 8 | UInt16(params[1]))
        }
        return true
    }
}
