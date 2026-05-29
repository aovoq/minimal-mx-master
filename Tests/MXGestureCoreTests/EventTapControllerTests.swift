import CoreGraphics
import XCTest
@testable import MXGestureCore

final class EventTapControllerTests: XCTestCase {
    func testRawXYMovementWatchdogReleasesAndLetsMovementThrough() {
        var now = 100.0
        let controller = EventTapController(currentTime: { now })
        controller.eventHandlingAllowed = { true }
        controller.policy = {
            GestureInputPolicy(mode: .hidRawXY, isHolding: true)
        }

        var panicReleaseCount = 0
        controller.onPanicRelease = {
            panicReleaseCount += 1
        }

        let firstMove = makeMouseMoved(dx: 10, dy: 0)
        XCTAssertNil(controller.handleForTesting(type: .mouseMoved, event: firstMove))
        XCTAssertEqual(panicReleaseCount, 0)

        now += EventTapController.maxDropDurationSeconds + 0.01
        let timedOutMove = makeMouseMoved(dx: 10, dy: 0)
        XCTAssertNotNil(controller.handleForTesting(type: .mouseMoved, event: timedOutMove))
        XCTAssertEqual(panicReleaseCount, 1)

        now += EventTapController.maxDropDurationSeconds + 0.01
        let latchedMove = makeMouseMoved(dx: 10, dy: 0)
        XCTAssertNotNil(controller.handleForTesting(type: .mouseMoved, event: latchedMove))
        XCTAssertEqual(panicReleaseCount, 1)
    }

    func testTapDisabledByTimeoutForcesReleaseAndLetsEventThrough() {
        let controller = EventTapController(currentTime: { 100 })
        controller.eventHandlingAllowed = { true }
        controller.policy = {
            GestureInputPolicy(mode: .hidRawXY, isHolding: true)
        }

        var panicReleaseCount = 0
        controller.onPanicRelease = {
            panicReleaseCount += 1
        }

        let disabledEvent = makeMouseMoved(dx: 0, dy: 0)
        XCTAssertNotNil(controller.handleForTesting(type: .tapDisabledByTimeout, event: disabledEvent))
        XCTAssertEqual(panicReleaseCount, 1)

        let nextMove = makeMouseMoved(dx: 10, dy: 0)
        XCTAssertNotNil(controller.handleForTesting(type: .mouseMoved, event: nextMove))
        XCTAssertEqual(panicReleaseCount, 1)
    }

    func testOtherMouseFallbackSignalsButNeverDropsTheButtonEvent() {
        let controller = EventTapController()
        controller.eventHandlingAllowed = { true }
        controller.policy = {
            GestureInputPolicy(mode: .eventTapFallback, isHolding: false)
        }

        var signals: [HIDGestureSignal] = []
        controller.onButtonSignal = {
            signals.append($0)
        }

        let down = makeOtherMouseEvent(type: .otherMouseDown, buttonNumber: 3)
        let up = makeOtherMouseEvent(type: .otherMouseUp, buttonNumber: 3)

        XCTAssertNotNil(controller.handleForTesting(type: .otherMouseDown, event: down))
        XCTAssertNotNil(controller.handleForTesting(type: .otherMouseUp, event: up))
        XCTAssertEqual(signals, [.buttonDown, .buttonUp])
    }

    func testDisabledPolicyAlwaysPassesMovement() {
        let controller = EventTapController()
        controller.eventHandlingAllowed = { true }
        controller.policy = {
            GestureInputPolicy(mode: .disabled, isHolding: true)
        }
        controller.onDelta = { _, _ in
            XCTFail("Disabled policy must not consume movement")
        }

        let move = makeMouseMoved(dx: 10, dy: 0)
        XCTAssertNotNil(controller.handleForTesting(type: .mouseMoved, event: move))
    }

    func testPermissionLossForcesReleaseAndNeverDropsRawXYMovement() {
        let controller = EventTapController()
        controller.eventHandlingAllowed = { false }
        controller.policy = {
            GestureInputPolicy(mode: .hidRawXY, isHolding: true)
        }

        var panicReleaseCount = 0
        controller.onPanicRelease = {
            panicReleaseCount += 1
        }

        let move = makeMouseMoved(dx: 10, dy: 0)
        XCTAssertNotNil(controller.handleForTesting(type: .mouseMoved, event: move))
        XCTAssertEqual(panicReleaseCount, 1)

        let nextMove = makeMouseMoved(dx: 10, dy: 0)
        XCTAssertNotNil(controller.handleForTesting(type: .mouseMoved, event: nextMove))
        XCTAssertEqual(panicReleaseCount, 1)
    }

    func testPermissionLossMakesFallbackButtonsCompletelyPassive() {
        let controller = EventTapController()
        controller.eventHandlingAllowed = { false }
        controller.policy = {
            GestureInputPolicy(mode: .eventTapFallback, isHolding: false)
        }

        var signals: [HIDGestureSignal] = []
        controller.onButtonSignal = {
            signals.append($0)
        }

        let down = makeOtherMouseEvent(type: .otherMouseDown, buttonNumber: 3)
        XCTAssertNotNil(controller.handleForTesting(type: .otherMouseDown, event: down))
        XCTAssertTrue(signals.isEmpty)
    }

    private func makeMouseMoved(dx: Int64, dy: Int64) -> CGEvent {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: .zero,
            mouseButton: .left
        )!
        event.setIntegerValueField(.mouseEventDeltaX, value: dx)
        event.setIntegerValueField(.mouseEventDeltaY, value: dy)
        return event
    }

    private func makeOtherMouseEvent(type: CGEventType, buttonNumber: Int64) -> CGEvent {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: .zero,
            mouseButton: .center
        )!
        event.setIntegerValueField(.mouseEventButtonNumber, value: buttonNumber)
        return event
    }
}
