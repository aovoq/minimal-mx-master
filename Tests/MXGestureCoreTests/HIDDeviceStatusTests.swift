import XCTest
@testable import MXGestureCore

final class HIDDeviceStatusTests: XCTestCase {
    func testBusyFallbackStatusKeepsDeviceConnectedButRawXYOff() {
        XCTAssertEqual(
            HIDDeviceStatus.hidBusyFallback(deviceName: "MX Master"),
            .init(connected: true, name: "MX Master (HID busy; fallback)", rawXYEnabled: false)
        )
    }

    func testOpenFailedStatusIsDisconnected() {
        XCTAssertEqual(
            HIDDeviceStatus.openFailed(returnName: "kIOReturnNotPermitted"),
            .init(connected: false, name: "HID manager open failed kIOReturnNotPermitted", rawXYEnabled: false)
        )
    }

    func testConfiguredStatusIncludesCIDAndRawXY() {
        let configuration = ReprogConfiguration(
            deviceIndex: 0xFF,
            featureIndex: 0x05,
            control: ReprogControl(cid: 0x00C3, taskID: 0, flags: 0x20, additionalFlags: 0x01),
            rawXYEnabled: true
        )

        XCTAssertEqual(
            HIDDeviceStatus.configured(deviceName: "MX Master", configuration: configuration),
            .init(
                connected: true,
                name: "MX Master CID 0xc3",
                rawXYEnabled: true,
                gestureConfigured: true
            )
        )
    }

    func testConfiguredStatusListsEveryDivertedCID() {
        let configuration = ReprogConfiguration(
            deviceIndex: 0xFF,
            featureIndex: 0x05,
            controls: [
                ReprogControl(cid: 0x00C3, taskID: 0, flags: 0x20, additionalFlags: 0x01),
                ReprogControl(cid: 0x0053, taskID: 0, flags: 0x20, additionalFlags: 0)
            ],
            rawXYEnabled: true
        )

        XCTAssertEqual(
            HIDDeviceStatus.configured(deviceName: "MX Master", configuration: configuration).name,
            "MX Master CID 0xc3, 0x53"
        )
    }

    func testConfiguredStatusAppendsSkippedControls() {
        let configuration = ReprogConfiguration(
            deviceIndex: 0xFF,
            featureIndex: 0x05,
            controls: [
                ReprogControl(cid: 0x0053, taskID: 0, flags: 0x20, additionalFlags: 0)
            ],
            rawXYEnabled: false,
            skipped: [SkippedControl(cid: 0x0050, reason: "not divertable")]
        )

        XCTAssertEqual(
            HIDDeviceStatus.configured(deviceName: "MX Master", configuration: configuration).name,
            "MX Master CID 0x53; skipped 0x50 not divertable"
        )
    }

    func testNativeButtonsStatusDoesNotRequestEventTapFallback() {
        XCTAssertEqual(
            HIDDeviceStatus.nativeButtons(deviceName: "MX Master"),
            .init(
                connected: true,
                name: "MX Master",
                rawXYEnabled: false,
                gestureConfigured: false,
                eventTapFallback: false
            )
        )
    }
}
