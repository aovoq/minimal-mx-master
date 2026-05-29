import XCTest
@testable import MXGestureCore

final class ReprogControlsTests: XCTestCase {
    func testPressedCIDParsingIgnoresZeroSlots() {
        let cids = ReprogControls.pressedCIDs(from: [0x00, 0xC3, 0, 0, 0x00, 0xD7])

        XCTAssertEqual(cids, [0x00C3, 0x00D7])
    }

    func testRawXYParsingUsesSignedBigEndianValues() {
        let xy = ReprogControls.rawXY(from: [0xFF, 0xFE, 0x00, 0x05])

        XCTAssertEqual(xy?.dx, -2)
        XCTAssertEqual(xy?.dy, 5)
    }

    func testGestureControlPrefersKnownGestureCID() {
        let generic = ReprogControl(cid: 0x0100, taskID: 0, flags: 0x20, additionalFlags: 0x01)
        let preferred = ReprogControl(cid: 0x00C3, taskID: 0, flags: 0x20, additionalFlags: 0)

        XCTAssertEqual(ReprogControls.chooseGestureControl(from: [generic, preferred])?.cid, 0x00C3)
    }

    func testControlParsingUsesHIDPPControlShape() {
        let control = ReprogControls.control(from: [0x00, 0xC3, 0x12, 0x34, 0x20, 0, 0, 0, 0x01])

        XCTAssertEqual(control?.cid, 0x00C3)
        XCTAssertEqual(control?.taskID, 0x1234)
        XCTAssertEqual(control?.flags, 0x20)
        XCTAssertEqual(control?.additionalFlags, 0x01)
    }

    func testControlParsingRejectsShortPayloads() {
        XCTAssertNil(ReprogControls.control(from: [0x00, 0xC3]))
    }

    func testReportingParamsUseCIDAndFlags() {
        XCTAssertEqual(
            ReprogControls.reportingParams(cid: 0x00C3, flags: ReprogControls.rawXYReportingFlags),
            [0x00, 0xC3, ReprogControls.rawXYReportingFlags, 0, 0]
        )
    }
}
