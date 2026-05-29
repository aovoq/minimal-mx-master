import CoreGraphics

extension EventTapController {
    func handleOtherMouseButton(type: CGEventType, event: CGEvent, policy: GestureInputPolicy) {
        let button = event.otherMouseButtonNumber
        AppLog.gesture.info("Other mouse \(type.rawValue) button \(button)")
        // Only emit a fallback signal for buttons we conceivably care about.
        // CRITICAL: never drop the event. We have no way to know whether the
        // press came from the MX Master vs. another device, so swallowing
        // would steal e.g. back/forward buttons from unrelated mice.
        guard policy.usesButtonFallback, button >= 3, let signal = type.hidButtonSignal else {
            return
        }
        onButtonSignal(signal)
    }

    func emitMovementFallback(from event: CGEvent) {
        let delta = event.mouseDelta
        if delta.dx != 0 || delta.dy != 0 {
            onDelta(delta.dx, delta.dy)
        }
    }
}
