import AppKit
import MXGestureCore

final class StatusMenuController: NSObject {
    var onToggleEnabled: ((Bool) -> Void)?
    var onOpenAccessibility: (() -> Void)?
    var onOpenInputMonitoring: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRestartHID: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let enabledItem = NSMenuItem()
    private let deviceItem = NSMenuItem()
    private let lastItem = NSMenuItem()
    private let accessibilityItem = NSMenuItem()
    private let inputMonitoringItem = NSMenuItem()
    private let mappingsItem = NSMenuItem()

    private var enabled: Bool

    init(config: AppConfig) {
        self.enabled = config.enabled
        super.init()
        buildMenu(config: config)
        statusItem.menu = menu
        statusItem.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MX")
        statusItem.button?.image?.isTemplate = true
        setEnabled(config.enabled)
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        enabledItem.title = enabled ? "Disable" : "Enable"
        statusItem.button?.contentTintColor = enabled ? nil : .disabledControlTextColor
    }

    func setDevice(_ name: String) {
        deviceItem.title = "Device: \(name)"
    }

    func setLast(_ event: String) {
        lastItem.title = "Last: \(event)"
    }

    func setHolding(_ holding: Bool) {
        if holding {
            statusItem.button?.contentTintColor = .controlAccentColor
        } else {
            statusItem.button?.contentTintColor = enabled ? nil : .disabledControlTextColor
        }
    }

    func setPermission(accessibility: Bool, inputMonitoring: Bool) {
        accessibilityItem.title = accessibility ? "Accessibility: Allowed" : "Accessibility: Required"
        accessibilityItem.isEnabled = !accessibility
        inputMonitoringItem.title = inputMonitoring ? "Input Monitoring: Allowed" : "Input Monitoring: Required"
        inputMonitoringItem.isEnabled = !inputMonitoring
    }

    func setConfig(_ config: AppConfig) {
        mappingsItem.title = mappingSummary(config: config)
    }

    private func buildMenu(config: AppConfig) {
        enabledItem.target = self
        enabledItem.action = #selector(toggleEnabled)
        menu.addItem(enabledItem)

        deviceItem.isEnabled = false
        deviceItem.title = "Device: Not connected"
        menu.addItem(deviceItem)

        lastItem.isEnabled = false
        lastItem.title = "Last: -"
        menu.addItem(lastItem)
        menu.addItem(.separator())

        mappingsItem.isEnabled = false
        mappingsItem.title = mappingSummary(config: config)
        menu.addItem(mappingsItem)

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        accessibilityItem.target = self
        accessibilityItem.action = #selector(openAccessibility)
        menu.addItem(accessibilityItem)

        inputMonitoringItem.target = self
        inputMonitoringItem.action = #selector(openInputMonitoring)
        menu.addItem(inputMonitoringItem)

        let restart = NSMenuItem(title: "Restart HID", action: #selector(restartHID), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func mappingSummary(config: AppConfig) -> String {
        GestureEvent.allCases
            .compactMap { event in
                config.shortcut(for: event).map { "\(event.rawValue): \($0.displayName)" }
            }
            .joined(separator: "  ")
    }

    @objc private func toggleEnabled() {
        onToggleEnabled?(!enabled)
    }

    @objc private func openAccessibility() {
        onOpenAccessibility?()
    }

    @objc private func openInputMonitoring() {
        onOpenInputMonitoring?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func restartHID() {
        onRestartHID?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
