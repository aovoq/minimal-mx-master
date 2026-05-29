import XCTest
@testable import MXGestureCore

final class GestureRecognizerTests: XCTestCase {
    func testShortPressEmitsClick() {
        let recognizer = GestureRecognizer(settings: .init(initialIgnoreMs: 0))
        var events: [GestureEvent] = []
        recognizer.onEvent = { events.append($0) }

        recognizer.handle(.buttonDown, now: 10)
        recognizer.handle(.buttonUp, now: 10.1)

        XCTAssertEqual(events, [.click])
    }

    func testHorizontalSwipeEmitsRightOnlyOnce() {
        let recognizer = GestureRecognizer(settings: .init(initialIgnoreMs: 0))
        var events: [GestureEvent] = []
        recognizer.onEvent = { events.append($0) }

        recognizer.handle(.buttonDown, now: 10)
        recognizer.handle(.rawXY(dx: 1, dy: 0), now: 10.01)
        recognizer.handle(.rawXY(dx: 60, dy: 5), now: 10.02)
        recognizer.handle(.rawXY(dx: 60, dy: 5), now: 10.03)
        recognizer.handle(.buttonUp, now: 10.04)

        XCTAssertEqual(events, [.right])
    }

    func testDirectionalGesturesCanRepeatImmediatelyAfterRelease() {
        let recognizer = GestureRecognizer(settings: .init(initialIgnoreMs: 0))
        var events: [GestureEvent] = []
        recognizer.onEvent = { events.append($0) }

        recognizer.handle(.buttonDown, now: 10)
        recognizer.handle(.rawXY(dx: 1, dy: 0), now: 10.01)
        recognizer.handle(.rawXY(dx: 60, dy: 0), now: 10.02)
        recognizer.handle(.buttonUp, now: 10.03)

        recognizer.handle(.buttonDown, now: 10.04)
        recognizer.handle(.rawXY(dx: -1, dy: 0), now: 10.05)
        recognizer.handle(.rawXY(dx: -60, dy: 0), now: 10.06)
        recognizer.handle(.buttonUp, now: 10.07)

        XCTAssertEqual(events, [.right, .left])
    }

    func testOppositeGestureCanTriggerFromFirstDeltaAfterInitialIgnore() {
        let recognizer = GestureRecognizer(settings: .init(initialIgnoreMs: 30))
        var events: [GestureEvent] = []
        recognizer.onEvent = { events.append($0) }

        recognizer.handle(.buttonDown, now: 10)
        recognizer.handle(.rawXY(dx: 1, dy: 0), now: 10.01)
        recognizer.handle(.rawXY(dx: 60, dy: 0), now: 10.04)
        recognizer.handle(.buttonUp, now: 10.05)

        recognizer.handle(.buttonDown, now: 10.06)
        recognizer.handle(.rawXY(dx: -60, dy: 0), now: 10.10)
        recognizer.handle(.buttonUp, now: 10.11)

        XCTAssertEqual(events, [.right, .left])
    }

    func testDiagonalMovementDoesNotBecomeClick() {
        let recognizer = GestureRecognizer(settings: .init(initialIgnoreMs: 0))
        var events: [GestureEvent] = []
        recognizer.onEvent = { events.append($0) }

        recognizer.handle(.buttonDown, now: 10)
        recognizer.handle(.rawXY(dx: 1, dy: 1), now: 10.01)
        recognizer.handle(.rawXY(dx: 70, dy: 70), now: 10.02)
        recognizer.handle(.buttonUp, now: 10.03)

        XCTAssertEqual(events, [])
    }

    func testCooldownSuppressesImmediateSecondPress() {
        let recognizer = GestureRecognizer(settings: .init(initialIgnoreMs: 0))
        var events: [GestureEvent] = []
        recognizer.onEvent = { events.append($0) }

        recognizer.handle(.buttonDown, now: 10)
        recognizer.handle(.buttonUp, now: 10.1)
        recognizer.handle(.buttonDown, now: 10.2)
        recognizer.handle(.buttonUp, now: 10.3)

        XCTAssertEqual(events, [.click])
    }
}
