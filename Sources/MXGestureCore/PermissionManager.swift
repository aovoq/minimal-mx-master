import AppKit
import ApplicationServices
import IOKit.hid

public enum PermissionManager {
    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public static var isInputMonitoringTrusted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    public static var requiredPermissionsGranted: Bool {
        isAccessibilityTrusted && isInputMonitoringTrusted
    }

    @discardableResult
    public static func requestAccessibilityPrompt() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @discardableResult
    public static func requestInputMonitoringPrompt() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    public static func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    public static func openInputMonitoringSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
