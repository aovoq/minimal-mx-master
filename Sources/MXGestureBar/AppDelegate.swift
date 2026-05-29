import AppKit
import MXGestureCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var config = AppConfig.load()
    private lazy var recognizer = GestureRecognizer(settings: config.gesture)
    private lazy var executor = ActionExecutor(config: config)
    private let hidManager = HIDDeviceManager()
    private let eventTap = EventTapController()
    private lazy var menu = StatusMenuController(config: config)
    private lazy var settingsWindow = SettingsWindowController(config: config)

    private var wakeObserver: NSObjectProtocol?
    private var permissionTimer: Timer?
    private var holdReleaseTimer: Timer?
    private var hidStatus = HIDDeviceStatus(connected: false, name: "Not connected", rawXYEnabled: false)
    private var captureServicesActive = false
    private var lastRawXYSignalAt: TimeInterval?

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireCallbacks()
        _ = executor
        menu.setDevice("Not connected")
        menu.setPermission(
            accessibility: PermissionManager.isAccessibilityTrusted,
            inputMonitoring: PermissionManager.isInputMonitoringTrusted
        )
        requestMissingPermissions()
        startServices()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartHID()
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        permissionTimer?.invalidate()
        holdReleaseTimer?.invalidate()
        stopCaptureServicesAndRelease()
    }

    private func wireCallbacks() {
        recognizer.onEvent = { [weak self] event in
            self?.handleGesture(event)
        }
        recognizer.onHoldChanged = { [weak self] holding in
            guard !holding else { return }
            DispatchQueue.main.async {
                self?.menu.setHolding(false)
            }
        }

        hidManager.onGestureSignal = { [weak self] signal in
            self?.handleGestureSignal(signal)
        }
        hidManager.onStatusChanged = { [weak self] status in
            AppLog.hid.info("Device status: \(status.name, privacy: .public)")
            self?.hidStatus = status
            self?.menu.setDevice(status.name)
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
            // Watchdog tripped — the tap was dropping movement for too long.
            // Force-release on the main thread to clear `isHolding` and prevent
            // any further drops. The user keeps cursor freedom no matter what.
            DispatchQueue.main.async {
                AppLog.gesture.error("Panic release fired from EventTap watchdog")
                self?.releaseHeldGesture()
            }
        }

        menu.onToggleEnabled = { [weak self] enabled in
            self?.setEnabled(enabled)
        }
        menu.onOpenAccessibility = {
            PermissionManager.requestAccessibilityPrompt()
            PermissionManager.openAccessibilitySettings()
        }
        menu.onOpenInputMonitoring = {
            PermissionManager.requestInputMonitoringPrompt()
            PermissionManager.openInputMonitoringSettings()
        }
        menu.onOpenSettings = { [weak self] in self?.openSettings() }
        menu.onRestartHID = { [weak self] in self?.restartHID() }
        menu.onQuit = { NSApp.terminate(nil) }

        settingsWindow.onSave = { [weak self] config in
            self?.applyConfig(config)
        }
    }

    private func startServices() {
        refreshPermission()
    }

    private func handleGesture(_ event: GestureEvent) {
        AppLog.gesture.info("Gesture event: \(event.rawValue, privacy: .public)")
        executor.execute(event)
        DispatchQueue.main.async { [weak self] in
            self?.menu.setLast(event.rawValue)
        }
    }

    private func handleGestureSignal(_ signal: HIDGestureSignal) {
        if case .rawXY = signal {
            lastRawXYSignalAt = Date().timeIntervalSinceReferenceDate
        }
        recognizer.handle(signal)
        if signal == .buttonDown {
            lastRawXYSignalAt = nil
            scheduleHoldFailsafe()
            DispatchQueue.main.async { [weak self] in self?.menu.setHolding(true) }
        } else if signal == .buttonUp {
            lastRawXYSignalAt = nil
            holdReleaseTimer?.invalidate()
            holdReleaseTimer = nil
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

    private func setEnabled(_ enabled: Bool) {
        config.enabled = enabled
        config.save()
        applyConfig(config)
        recognizer.forceRelease()
        menu.setEnabled(enabled)

        if enabled {
            refreshPermission()
        } else {
            stopCaptureServicesAndRelease()
        }
    }

    private func restartHID() {
        releaseHeldGesture()
        guard config.enabled, PermissionManager.requiredPermissionsGranted else {
            stopCaptureServicesAndRelease()
            return
        }
        hidManager.restart()
        captureServicesActive = true
        _ = eventTap.start()
    }

    private func refreshPermission() {
        let accessibility = PermissionManager.isAccessibilityTrusted
        let inputMonitoring = PermissionManager.isInputMonitoringTrusted
        menu.setPermission(accessibility: accessibility, inputMonitoring: inputMonitoring)

        guard config.enabled, accessibility, inputMonitoring else {
            stopCaptureServicesAndRelease()
            return
        }

        startCaptureServices()
    }

    private func startCaptureServices() {
        hidManager.start()
        captureServicesActive = true
        _ = eventTap.start()
    }

    private func stopCaptureServicesAndRelease() {
        hidStatus = HIDDeviceStatus(connected: false, name: "Not connected", rawXYEnabled: false)
        eventTap.stop()
        if captureServicesActive {
            hidManager.stop()
            captureServicesActive = false
        }
        releaseHeldGesture()
    }

    private func releaseHeldGesture() {
        recognizer.forceRelease()
        menu.setHolding(false)
        holdReleaseTimer?.invalidate()
        holdReleaseTimer = nil
    }

    private func requestMissingPermissions() {
        if !PermissionManager.isAccessibilityTrusted {
            PermissionManager.requestAccessibilityPrompt()
        }
        if !PermissionManager.isInputMonitoringTrusted {
            PermissionManager.requestInputMonitoringPrompt()
        }
    }

    private func openSettings() {
        settingsWindow.update(config: config)
        settingsWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyConfig(_ config: AppConfig) {
        self.config = config
        executor.update(config: config)
        recognizer.update(settings: config.gesture)
        menu.setConfig(config)
    }
}
