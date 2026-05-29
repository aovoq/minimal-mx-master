import XCTest
@testable import MXGestureCore

final class GestureInputPolicyTests: XCTestCase {
    func testDisabledModeUsesNoFallbacks() {
        let policy = GestureInputPolicy(
            isEnabled: false,
            hidStatus: .init(connected: true, name: "MX", rawXYEnabled: true, gestureConfigured: true),
            isHolding: true
        )

        XCTAssertEqual(policy.mode, .disabled)
        XCTAssertFalse(policy.usesButtonFallback)
        XCTAssertFalse(policy.capturesMovement)
        XCTAssertFalse(policy.usesMovementFallback)
        XCTAssertFalse(policy.blocksMovement)
    }

    func testEventTapFallbackUsesButtonAndMovementFallbacksWhileHolding() {
        // Fallback should only engage when a supported device is connected but
        // we failed to program its gesture button (e.g. unknown firmware).
        let policy = GestureInputPolicy(
            isEnabled: true,
            hidStatus: .init(connected: true, name: "MX", rawXYEnabled: false),
            isHolding: true
        )

        XCTAssertEqual(policy.mode, .eventTapFallback)
        XCTAssertTrue(policy.usesButtonFallback)
        XCTAssertTrue(policy.usesMovementFallback)
        XCTAssertFalse(policy.blocksMovement)
    }

    func testDisconnectedDeviceStaysCompletelyPassive() {
        // Without a connected device we must not touch input at all — touching
        // unrelated mouse buttons used to steal back/forward from other devices
        // and could deadlock the user out of cursor movement.
        let policy = GestureInputPolicy(
            isEnabled: true,
            hidStatus: .init(connected: false, name: "Not connected", rawXYEnabled: false),
            isHolding: true
        )

        XCTAssertEqual(policy.mode, .disabled)
        XCTAssertFalse(policy.usesButtonFallback)
        XCTAssertFalse(policy.capturesMovement)
        XCTAssertFalse(policy.blocksMovement)
    }

    func testHIDRawXYBlocksMouseMovementWhileHolding() {
        let policy = GestureInputPolicy(
            isEnabled: true,
            hidStatus: .init(connected: true, name: "MX", rawXYEnabled: true, gestureConfigured: true),
            isHolding: true
        )

        XCTAssertEqual(policy.mode, .hidRawXY)
        XCTAssertFalse(policy.usesButtonFallback)
        XCTAssertFalse(policy.usesMovementFallback)
        XCTAssertTrue(policy.blocksMovement)
    }
}
