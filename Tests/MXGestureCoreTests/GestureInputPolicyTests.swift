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
        let policy = GestureInputPolicy(
            isEnabled: true,
            hidStatus: .init(connected: false, name: "Not connected", rawXYEnabled: false),
            isHolding: true
        )

        XCTAssertEqual(policy.mode, .eventTapFallback)
        XCTAssertTrue(policy.usesButtonFallback)
        XCTAssertTrue(policy.usesMovementFallback)
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
