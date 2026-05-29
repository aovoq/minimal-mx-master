import AppKit
import MXGestureCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var config = AppConfig.load()
    private lazy var runtime = GestureRuntimeController(config: config)
    private lazy var menu = StatusMenuController(config: config)
    private lazy var settingsWindow = SettingsWindowController(config: config)

    private var wakeObserver: NSObjectProtocol?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireCallbacks()
        showInitialMenuState()
        requestMissingPermissions()
        refreshPermission()
        installWakeObserver()
        installPermissionTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        permissionTimer?.invalidate()
        runtime.stopAndRelease()
    }

    private func wireCallbacks() {
        runtime.onDeviceNameChanged = { [weak self] name in
            self?.menu.setDevice(name)
        }
        runtime.onGestureEvent = { [weak self] event in
            self?.menu.setLast(event.rawValue)
        }
        runtime.onHoldingChanged = { [weak self] holding in
            self?.menu.setHolding(holding)
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

    private func showInitialMenuState() {
        menu.setDevice(HIDDeviceStatus.notConnected.name)
        updatePermissionMenu(with: .current)
    }

    private func installWakeObserver() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartHID()
        }
    }

    private func installPermissionTimer() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
    }

    private func setEnabled(_ enabled: Bool) {
        config.enabled = enabled
        config.save()
        applyConfig(config)
        runtime.forceReleaseGesture()
        menu.setEnabled(enabled)

        if enabled {
            refreshPermission()
        } else {
            runtime.stopAndRelease()
        }
    }

    private func restartHID() {
        guard canCapture(with: .current) else {
            runtime.stopAndRelease()
            return
        }
        runtime.restartCaptureServices()
    }

    private func refreshPermission() {
        let permissions = PermissionSnapshot.current
        updatePermissionMenu(with: permissions)

        guard canCapture(with: permissions) else {
            runtime.stopAndRelease()
            return
        }

        runtime.startCaptureServices()
    }

    private func canCapture(with permissions: PermissionSnapshot) -> Bool {
        config.enabled && permissions.requiredPermissionsGranted
    }

    private func updatePermissionMenu(with permissions: PermissionSnapshot) {
        menu.setPermission(
            accessibility: permissions.accessibility,
            inputMonitoring: permissions.inputMonitoring
        )
    }

    private func requestMissingPermissions() {
        PermissionSnapshot.current.requestMissingPrompts()
    }

    private func openSettings() {
        settingsWindow.update(config: config)
        settingsWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyConfig(_ config: AppConfig) {
        self.config = config
        runtime.update(config: config)
        menu.setConfig(config)
    }
}
