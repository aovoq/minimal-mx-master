import XCTest
@testable import MXGestureCore

final class GestureRuntimeStateTests: XCTestCase {
    func testHIDRawXYFallbackActivatesUntilRawXYArrivesAndAfterDelay() {
        var state = GestureRuntimeState(
            hidStatus: .init(connected: true, name: "MX", rawXYEnabled: true, gestureConfigured: true)
        )

        XCTAssertEqual(
            state.inputPolicy(isEnabled: true, isHolding: true, now: 10).mode,
            .hidRawXYWithMovementFallback
        )

        XCTAssertEqual(state.observe(.rawXY(dx: 4, dy: -2), at: 10), .none)
        XCTAssertEqual(
            state.inputPolicy(isEnabled: true, isHolding: true, now: 10.1).mode,
            .hidRawXY
        )
        XCTAssertEqual(
            state.inputPolicy(isEnabled: true, isHolding: true, now: 10.16).mode,
            .hidRawXYWithMovementFallback
        )
    }

    func testButtonSignalsDescribeHoldSideEffectsAndClearRawXYFreshness() {
        var state = GestureRuntimeState(
            hidStatus: .init(connected: true, name: "MX", rawXYEnabled: true, gestureConfigured: true)
        )

        XCTAssertEqual(state.observe(.rawXY(dx: 1, dy: 1), at: 20), .none)
        XCTAssertFalse(state.rawXYFallbackActive(isHolding: true, now: 20.01))

        XCTAssertEqual(state.observe(.buttonDown, at: 20.02), .beginHold)
        XCTAssertTrue(state.rawXYFallbackActive(isHolding: true, now: 20.03))

        XCTAssertEqual(state.observe(.buttonUp, at: 20.04), .endHold)
        XCTAssertTrue(state.rawXYFallbackActive(isHolding: true, now: 20.05))
    }

    func testDisconnectedOrDisabledStateStaysPassive() {
        var state = GestureRuntimeState(
            hidStatus: .init(connected: true, name: "MX", rawXYEnabled: true, gestureConfigured: true)
        )

        XCTAssertEqual(
            state.inputPolicy(isEnabled: false, isHolding: true, now: 30).mode,
            .disabled
        )

        state.resetStatus()
        XCTAssertEqual(state.hidStatus, .notConnected)
        XCTAssertEqual(
            state.inputPolicy(isEnabled: true, isHolding: true, now: 30).mode,
            .disabled
        )
    }
}
