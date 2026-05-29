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

    private var holdReleaseTimer: Timer?
    private var hidStatus = HIDDeviceStatus.notConnected
    private var captureServicesActive = false
    private var lastRawXYSignalAt: TimeInterval?

    init(config: AppConfig) {
        self.config = config
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
        hidStatus = .notConnected
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
            self?.hidStatus = status
            self?.onDeviceNameChanged?(status.name)
        }

        eventTap.eventHandlingAllowed = {
            PermissionManager.isAccessibilityTrusted
        }
        eventTap.policy = { [weak self] in
            guard let self else {
                return GestureInputPolicy(mode: .disabled, isHolding: false)
            }
            return GestureInputPolicy(
                isEnabled: self.config.enabled,
                hidStatus: self.hidStatus,
                isHolding: self.recognizer.isHolding,
                rawXYFallbackActive: self.rawXYFallbackActive
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
        if case .rawXY = signal {
            lastRawXYSignalAt = Date().timeIntervalSinceReferenceDate
        }
        recognizer.handle(signal)

        switch signal {
        case .buttonDown:
            lastRawXYSignalAt = nil
            scheduleHoldFailsafe()
            publishHolding(true)
        case .buttonUp:
            lastRawXYSignalAt = nil
            cancelHoldFailsafe()
        case .rawXY:
            break
        }
    }

    private var rawXYFallbackActive: Bool {
        guard hidStatus.gestureConfigured, hidStatus.rawXYEnabled, recognizer.isHolding else {
            return false
        }
        guard let lastRawXYSignalAt else { return true }
        return Date().timeIntervalSinceReferenceDate - lastRawXYSignalAt > 0.15
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
