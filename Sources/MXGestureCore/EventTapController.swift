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
    public var eventHandlingAllowed: () -> Bool = {
        PermissionManager.isAccessibilityTrusted
    }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let currentTime: () -> TimeInterval
    private var dropWatchdog: EventDropWatchdog

    public convenience init() {
        self.init(currentTime: CFAbsoluteTimeGetCurrent)
    }

    init(currentTime: @escaping () -> TimeInterval) {
        self.currentTime = currentTime
        self.dropWatchdog = EventDropWatchdog(maxDropDuration: Self.maxDropDurationSeconds)
    }

    @discardableResult
    public func start() -> Bool {
        guard tap == nil, eventHandlingAllowed() else { return false }

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
        if let tap {
            CFMachPortInvalidate(tap)
        }
        source = nil
        tap = nil
        dropWatchdog.reset()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard eventHandlingAllowed() else {
            return passThroughAfterPermissionLoss(event)
        }

        if type.isTapDisabledNotification {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // Tap was disabled while in the event stream. Assume any in-flight
            // gesture is stale and force the recognizer out of hold state.
            AppLog.gesture.error("EventTap disabled by system/user input; forcing release")
            tripPanicRelease()
            return Unmanaged.passUnretained(event)
        }

        if event.isMXGestureSyntheticEvent {
            return Unmanaged.passUnretained(event)
        }

        let inputPolicy = policy()

        // Fail-safe #1: when disabled, never touch any event.
        if inputPolicy.mode == .disabled {
            resetDropTracking()
            return Unmanaged.passUnretained(event)
        }

        if type.isOtherMouseButtonEvent {
            handleOtherMouseButton(type: type, event: event, policy: inputPolicy)
            return Unmanaged.passUnretained(event)
        }

        guard inputPolicy.capturesMovement else {
            resetDropTracking()
            return Unmanaged.passUnretained(event)
        }

        if inputPolicy.usesMovementFallback {
            emitMovementFallback(from: event)
        }

        guard inputPolicy.blocksMovement else {
            resetDropTracking()
            return Unmanaged.passUnretained(event)
        }

        // We are about to drop a cursor-movement event. Track how long we have
        // been doing this consecutively. If the watchdog trips, give up and
        // restore cursor freedom — the user must never be locked out.
        switch dropWatchdog.handleDroppedMovement(at: currentTime()) {
        case .drop:
            return nil
        case let .releaseAndPassThrough(duration):
            AppLog.gesture.error(
                "EventTap watchdog: movement dropped for \(duration)s; forcing release"
            )
            tripPanicRelease()
            return Unmanaged.passUnretained(event)
        case .passThrough:
            return Unmanaged.passUnretained(event)
        }
    }

    func handleForTesting(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        handle(type: type, event: event)
    }

    private func tripPanicRelease() {
        if dropWatchdog.trip() {
            onPanicRelease()
        }
    }

    private func resetDropTracking() {
        dropWatchdog.reset()
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<EventTapController>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        return controller.handle(type: type, event: event)
    }
}

private extension EventTapController {
    func passThroughAfterPermissionLoss(_ event: CGEvent) -> Unmanaged<CGEvent> {
        if !dropWatchdog.isPanicLatched {
            AppLog.gesture.error("Event handling unavailable; passing input through")
        }
        tripPanicRelease()
        return Unmanaged.passUnretained(event)
    }
}
