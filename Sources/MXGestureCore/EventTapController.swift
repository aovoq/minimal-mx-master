import CoreGraphics
import Foundation

public final class EventTapController {
    /// Hard ceiling on how long we may keep dropping movement events before we
    /// abandon the gesture and restore cursor freedom. Protects the user from
    /// being locked out if `isHolding` ever fails to clear (HID disconnect,
    /// missed buttonUp, runaway state, etc.).
    public static let maxDropDurationSeconds: TimeInterval = 1.2

    public var policy: () -> GestureInputPolicy = {
        GestureInputPolicy(mode: .disabled, isHolding: false)
    }
    public var onDelta: (Int, Int) -> Void = { _, _ in }
    public var onButtonSignal: (HIDGestureSignal) -> Void = { _ in }
    /// Fired when the safety watchdog forces a release because movement has
    /// been dropped for too long without `buttonUp`.
    public var onPanicRelease: () -> Void = {}

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let currentTime: () -> TimeInterval
    private var dropStartedAt: TimeInterval?
    private var panicLatched = false

    public convenience init() {
        self.init(currentTime: CFAbsoluteTimeGetCurrent)
    }

    init(currentTime: @escaping () -> TimeInterval) {
        self.currentTime = currentTime
    }

    @discardableResult
    public func start() -> Bool {
        guard tap == nil, PermissionManager.isAccessibilityTrusted else { return false }

        let mask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: Self.callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        tap = newTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: newTap, enable: true)
        return true
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        source = nil
        tap = nil
        dropStartedAt = nil
        panicLatched = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // Tap was disabled while in the event stream. Assume any in-flight
            // gesture is stale and force the recognizer out of hold state.
            AppLog.gesture.error("EventTap disabled by system/user input; forcing release")
            tripPanicRelease()
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == ActionExecutor.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        let inputPolicy = policy()

        // Fail-safe #1: when disabled, never touch any event.
        if inputPolicy.mode == .disabled {
            resetDropTracking()
            return Unmanaged.passUnretained(event)
        }

        if type == .otherMouseDown || type == .otherMouseUp {
            let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            AppLog.gesture.info("Other mouse \(type.rawValue) button \(button)")
            // Only emit a fallback signal for buttons we conceivably care about.
            // CRITICAL: never drop the event. We have no way to know whether the
            // press came from the MX Master vs. another device, so swallowing
            // would steal e.g. back/forward buttons from unrelated mice.
            if inputPolicy.usesButtonFallback, button >= 3 {
                onButtonSignal(type == .otherMouseDown ? .buttonDown : .buttonUp)
            }
            return Unmanaged.passUnretained(event)
        }

        guard inputPolicy.capturesMovement else {
            resetDropTracking()
            return Unmanaged.passUnretained(event)
        }

        if inputPolicy.usesMovementFallback {
            let dx = Int(event.getIntegerValueField(.mouseEventDeltaX))
            let dy = Int(event.getIntegerValueField(.mouseEventDeltaY))
            if dx != 0 || dy != 0 {
                onDelta(dx, dy)
            }
        }

        guard inputPolicy.blocksMovement else {
            resetDropTracking()
            return Unmanaged.passUnretained(event)
        }

        // We are about to drop a cursor-movement event. Track how long we have
        // been doing this consecutively. If the watchdog trips, give up and
        // restore cursor freedom — the user must never be locked out.
        let now = currentTime()
        if dropStartedAt == nil { dropStartedAt = now }

        if let started = dropStartedAt,
           now - started > Self.maxDropDurationSeconds,
           !panicLatched {
            AppLog.gesture.error(
                "EventTap watchdog: movement dropped for \(now - started)s; forcing release"
            )
            tripPanicRelease()
            // Let this event through too.
            return Unmanaged.passUnretained(event)
        }

        if panicLatched {
            // Stay open until policy stops requesting drops (i.e. buttonUp).
            return Unmanaged.passUnretained(event)
        }

        return nil
    }

    func handleForTesting(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        handle(type: type, event: event)
    }

    private func tripPanicRelease() {
        dropStartedAt = nil
        guard !panicLatched else { return }
        panicLatched = true
        onPanicRelease()
    }

    private func resetDropTracking() {
        dropStartedAt = nil
        panicLatched = false
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<EventTapController>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        return controller.handle(type: type, event: event)
    }
}
