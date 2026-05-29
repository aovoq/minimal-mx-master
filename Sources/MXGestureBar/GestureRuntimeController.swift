import Foundation
import MXGestureCore

final class GestureRuntimeController {
    var onDeviceNameChanged: ((String) -> Void)?
    var onGestureEvent: ((GestureEvent) -> Void)?
    var onHoldingChanged: ((Bool) -> Void)?

    private var config: AppConfig
    private lazy var recognizer = GestureRecognizer(settings: config.gesture)
    private lazy var executor = ActionExecutor(config: config)
    private let hidManager = HIDDeviceManager()
    private let eventTap = EventTapController()
    private let currentTime: () -> TimeInterval

    private var holdReleaseTimer: Timer?
    private var state = GestureRuntimeState()
    private var captureServicesActive = false

    init(
        config: AppConfig,
        currentTime: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }
    ) {
        self.config = config
        self.currentTime = currentTime
        wireCallbacks()
        _ = executor
    }

    deinit {
        holdReleaseTimer?.invalidate()
    }

    func update(config: AppConfig) {
        self.config = config
        executor.update(config: config)
        recognizer.update(settings: config.gesture)
    }

    func startCaptureServices() {
        hidManager.start()
        captureServicesActive = true
        _ = eventTap.start()
    }

    func restartCaptureServices() {
        releaseHeldGesture()
        hidManager.restart()
        captureServicesActive = true
        _ = eventTap.start()
    }

    func stopAndRelease() {
        state.resetStatus()
        eventTap.stop()
        if captureServicesActive {
            hidManager.stop()
            captureServicesActive = false
        }
        releaseHeldGesture()
    }

    func forceReleaseGesture() {
        releaseHeldGesture()
    }

    private func wireCallbacks() {
        recognizer.onEvent = { [weak self] event in
            self?.handleGesture(event)
        }
        recognizer.onHoldChanged = { [weak self] holding in
            guard !holding else { return }
            self?.publishHolding(false)
        }

        hidManager.onGestureSignal = { [weak self] signal in
            self?.handleGestureSignal(signal)
        }
        hidManager.onStatusChanged = { [weak self] status in
            AppLog.hid.info("Device status: \(status.name, privacy: .public)")
            self?.state.update(status: status)
            self?.onDeviceNameChanged?(status.name)
        }

        eventTap.eventHandlingAllowed = {
            PermissionManager.isAccessibilityTrusted
        }
        eventTap.policy = { [weak self] in
            guard let self else {
                return GestureInputPolicy(mode: .disabled, isHolding: false)
            }
            return self.state.inputPolicy(
                isEnabled: self.config.enabled,
                isHolding: self.recognizer.isHolding,
                now: self.currentTime()
            )
        }
        eventTap.onDelta = { [weak self] dx, dy in
            self?.recognizer.handle(.rawXY(dx: dx, dy: dy))
        }
        eventTap.onButtonSignal = { [weak self] signal in
            self?.handleGestureSignal(signal)
        }
        eventTap.onPanicRelease = { [weak self] in
            DispatchQueue.main.async {
                AppLog.gesture.error("Panic release fired from EventTap watchdog")
                self?.releaseHeldGesture()
            }
        }
    }

    private func handleGesture(_ event: GestureEvent) {
        AppLog.gesture.info("Gesture event: \(event.rawValue, privacy: .public)")
        executor.execute(event)
        DispatchQueue.main.async { [weak self] in
            self?.onGestureEvent?(event)
        }
    }

    private func handleGestureSignal(_ signal: HIDGestureSignal) {
        let effect = state.observe(signal, at: currentTime())
        recognizer.handle(signal)
        apply(effect)
    }

    private func apply(_ effect: GestureRuntimeState.SignalEffect) {
        switch effect {
        case .beginHold:
            scheduleHoldFailsafe()
            publishHolding(true)
        case .endHold:
            cancelHoldFailsafe()
        case .none:
            break
        }
    }

    private func scheduleHoldFailsafe() {
        holdReleaseTimer?.invalidate()
        holdReleaseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.releaseHeldGesture()
        }
    }

    private func cancelHoldFailsafe() {
        holdReleaseTimer?.invalidate()
        holdReleaseTimer = nil
    }

    private func releaseHeldGesture() {
        recognizer.forceRelease()
        publishHolding(false)
        cancelHoldFailsafe()
    }

    private func publishHolding(_ holding: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onHoldingChanged?(holding)
        }
    }
}
