import XCTest
@testable import MXGestureCore

final class EventDropWatchdogTests: XCTestCase {
    func testDroppedMovementTripsOnlyAfterDurationLimit() {
        var watchdog = EventDropWatchdog(maxDropDuration: 1.2)

        XCTAssertEqual(watchdog.handleDroppedMovement(at: 10), .drop)
        XCTAssertEqual(watchdog.handleDroppedMovement(at: 11.2), .drop)

        switch watchdog.handleDroppedMovement(at: 11.21) {
        case let .releaseAndPassThrough(duration):
            XCTAssertEqual(duration, 1.21, accuracy: 0.0001)
        default:
            XCTFail("Expected watchdog to release and pass movement through")
        }
    }

    func testPanicLatchPassesMovementThroughUntilReset() {
        var watchdog = EventDropWatchdog(maxDropDuration: 1.2)

        XCTAssertTrue(watchdog.trip())
        XCTAssertFalse(watchdog.trip())
        XCTAssertEqual(watchdog.handleDroppedMovement(at: 10), .passThrough)

        watchdog.reset()
        XCTAssertEqual(watchdog.handleDroppedMovement(at: 10), .drop)
    }
}
