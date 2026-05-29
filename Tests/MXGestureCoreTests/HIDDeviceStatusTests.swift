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
}
