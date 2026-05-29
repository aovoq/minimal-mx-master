import MXGestureCore

struct PermissionSnapshot {
    let accessibility: Bool
    let inputMonitoring: Bool

    var requiredPermissionsGranted: Bool {
        accessibility && inputMonitoring
    }

    static var current: PermissionSnapshot {
        PermissionSnapshot(
            accessibility: PermissionManager.isAccessibilityTrusted,
            inputMonitoring: PermissionManager.isInputMonitoringTrusted
        )
    }

    func requestMissingPrompts() {
        if !accessibility {
            PermissionManager.requestAccessibilityPrompt()
        }
        if !inputMonitoring {
            PermissionManager.requestInputMonitoringPrompt()
        }
    }
}
