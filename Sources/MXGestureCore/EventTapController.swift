import CoreGraphics
import Foundation

public final class EventTapController {
    public var policy: () -> GestureInputPolicy = {
        GestureInputPolicy(mode: .disabled, isHolding: false)
    }
    public var onDelta: (Int, Int) -> Void = { _, _ in }
    public var onButtonSignal: (HIDGestureSignal) -> Void = { _ in }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    public init() {}

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
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == ActionExecutor.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        if type == .otherMouseDown || type == .otherMouseUp {
            let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            AppLog.gesture.info("Other mouse \(type.rawValue) button \(button)")
            guard policy().usesButtonFallback, button >= 3 else {
                return Unmanaged.passUnretained(event)
            }
            onButtonSignal(type == .otherMouseDown ? .buttonDown : .buttonUp)
            return nil
        }

        let inputPolicy = policy()
        guard inputPolicy.capturesMovement else {
            return Unmanaged.passUnretained(event)
        }

        if inputPolicy.usesMovementFallback {
            let dx = Int(event.getIntegerValueField(.mouseEventDeltaX))
            let dy = Int(event.getIntegerValueField(.mouseEventDeltaY))
            if dx != 0 || dy != 0 {
                onDelta(dx, dy)
            }
        }
        return inputPolicy.blocksMovement ? nil : Unmanaged.passUnretained(event)
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<EventTapController>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        return controller.handle(type: type, event: event)
    }
}
