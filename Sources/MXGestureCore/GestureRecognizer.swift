import Foundation

public final class GestureRecognizer {
    public struct Settings: Codable, Equatable {
        public var threshold: Double
        public var deadzone: Double
        public var timeoutMs: Double
        public var cooldownMs: Double
        public var initialIgnoreMs: Double

        public init(
            threshold: Double = 50,
            deadzone: Double = 40,
            timeoutMs: Double = 3000,
            cooldownMs: Double = 500,
            initialIgnoreMs: Double = 30
        ) {
            self.threshold = threshold
            self.deadzone = deadzone
            self.timeoutMs = timeoutMs
            self.cooldownMs = cooldownMs
            self.initialIgnoreMs = initialIgnoreMs
        }
    }

    public var onEvent: ((GestureEvent) -> Void)?
    public var onHoldChanged: ((Bool) -> Void)?

    private enum Phase {
        case idle
        case holding(startedAt: TimeInterval, ignoreUntil: TimeInterval, ignoredFirst: Bool)
        case triggered
        case cooldown(until: TimeInterval)
    }

    private var settings: Settings
    private var phase: Phase = .idle
    private var accumX = 0.0
    private var accumY = 0.0
    private var gestureLikeMovement = false

    public init(settings: Settings = Settings()) {
        self.settings = settings
    }

    public var isHolding: Bool {
        if case .holding = phase { return true }
        if case .triggered = phase { return true }
        return false
    }

    public func update(settings: Settings) {
        self.settings = settings
    }

    public func handle(_ signal: HIDGestureSignal) {
        handle(signal, now: Date().timeIntervalSinceReferenceDate)
    }

    public func handle(_ signal: HIDGestureSignal, now: TimeInterval) {
        switch signal {
        case .buttonDown:
            buttonDown(now: now)
        case .buttonUp:
            buttonUp(now: now)
        case let .rawXY(dx, dy):
            move(dx: dx, dy: dy, now: now)
        }
    }

    public func forceRelease() {
        forceRelease(now: Date().timeIntervalSinceReferenceDate)
    }

    public func forceRelease(now: TimeInterval) {
        guard isHolding else { return }
        enterCooldown(now: now)
    }

    private func buttonDown(now: TimeInterval) {
        if case let .cooldown(until) = phase, now < until { return }

        accumX = 0
        accumY = 0
        gestureLikeMovement = false
        phase = .holding(
            startedAt: now,
            ignoreUntil: now + settings.initialIgnoreMs / 1000,
            ignoredFirst: false
        )
        onHoldChanged?(true)
    }

    private func buttonUp(now: TimeInterval) {
        switch phase {
        case .holding:
            if !gestureLikeMovement {
                onEvent?(.click)
            }
            enterCooldown(now: now)
        case .triggered:
            finishHold()
        default:
            break
        }
    }

    private func move(dx: Int, dy: Int, now: TimeInterval) {
        guard case let .holding(startedAt, ignoreUntil, ignoredFirst) = phase else { return }

        if now - startedAt > settings.timeoutMs / 1000 {
            forceRelease(now: now)
            return
        }

        if !ignoredFirst || now < ignoreUntil {
            phase = .holding(startedAt: startedAt, ignoreUntil: ignoreUntil, ignoredFirst: true)
            return
        }

        accumX += Double(dx)
        accumY += Double(dy)

        let absX = abs(accumX)
        let absY = abs(accumY)
        let dominant = max(absX, absY)
        guard dominant >= settings.threshold else { return }

        gestureLikeMovement = true
        if absX >= absY, absY <= settings.deadzone {
            trigger(accumX < 0 ? .left : .right)
        } else if absY > absX, absX <= settings.deadzone {
            trigger(accumY < 0 ? .up : .down)
        }
    }

    private func trigger(_ event: GestureEvent) {
        phase = .triggered
        onEvent?(event)
    }

    private func enterCooldown(now: TimeInterval) {
        phase = .cooldown(until: now + settings.cooldownMs / 1000)
        onHoldChanged?(false)
    }

    private func finishHold() {
        phase = .idle
        onHoldChanged?(false)
    }

}
