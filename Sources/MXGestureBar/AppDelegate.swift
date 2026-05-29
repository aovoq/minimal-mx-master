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

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireCallbacks()
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

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        permissionTimer?.invalidate()
        holdReleaseTimer?.invalidate()
        eventTap.stop()
        hidManager.stop()
    }

    private func wireCallbacks() {
        recognizer.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                self?.handleGesture(event)
            }
        }
        recognizer.onHoldChanged = { [weak self] holding in
            if !holding { self?.menu.setHolding(false) }
        }

        hidManager.onGestureSignal = { [weak self] signal in
            self?.handleGestureSignal(signal)
        }
        hidManager.onStatusChanged = { [weak self] status in
            AppLog.hid.info("Device status: \(status.name, privacy: .public)")
            self?.hidStatus = status
            self?.menu.setDevice(status.name)
        }

        eventTap.policy = { [weak self] in
            guard let self else {
                return GestureInputPolicy(mode: .disabled, isHolding: false)
            }
            return GestureInputPolicy(
                isEnabled: self.config.enabled,
                hidStatus: self.hidStatus,
                isHolding: self.recognizer.isHolding
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
                self?.recognizer.forceRelease()
                self?.menu.setHolding(false)
                self?.holdReleaseTimer?.invalidate()
                self?.holdReleaseTimer = nil
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
        if config.enabled {
            hidManager.start()
        }
        _ = eventTap.start()
    }

    private func handleGesture(_ event: GestureEvent) {
        AppLog.gesture.info("Gesture event: \(event.rawValue, privacy: .public)")
        menu.setLast(event.rawValue)
        executor.execute(event)
    }

    private func handleGestureSignal(_ signal: HIDGestureSignal) {
        recognizer.handle(signal)
        if signal == .buttonDown {
            scheduleHoldFailsafe()
            DispatchQueue.main.async { [weak self] in self?.menu.setHolding(true) }
        } else if signal == .buttonUp {
            holdReleaseTimer?.invalidate()
            holdReleaseTimer = nil
        }
    }

    private func scheduleHoldFailsafe() {
        holdReleaseTimer?.invalidate()
        holdReleaseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.recognizer.forceRelease()
            self?.menu.setHolding(false)
            self?.holdReleaseTimer = nil
        }
    }

    private func setEnabled(_ enabled: Bool) {
        config.enabled = enabled
        config.save()
        applyConfig(config)
        recognizer.forceRelease()
        menu.setEnabled(enabled)

        if enabled {
            hidManager.start()
        } else {
            hidManager.stop()
        }
    }

    private func restartHID() {
        recognizer.forceRelease()
        hidManager.restart()
    }

    private func refreshPermission() {
        let accessibility = PermissionManager.isAccessibilityTrusted
        let inputMonitoring = PermissionManager.isInputMonitoringTrusted
        menu.setPermission(accessibility: accessibility, inputMonitoring: inputMonitoring)
        if accessibility {
            _ = eventTap.start()
        }
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
