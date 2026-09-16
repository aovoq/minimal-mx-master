import CoreGraphics
import Foundation

public final class ActionExecutor {
    private let queue = DispatchQueue(label: "dev.aovoq.MXGestureBar.ActionExecutor")
    private var enabled: Bool
    private var config: AppConfig
    private let eventSource =
        CGEventSource(stateID: .hidSystemState) ??
        CGEventSource(stateID: .combinedSessionState)

    public init(config: AppConfig) {
        self.config = config
        self.enabled = config.enabled
        eventSource?.localEventsSuppressionInterval = 0
    }

    public func update(config: AppConfig) {
        queue.async { [weak self] in
            self?.config = config
            self?.enabled = config.enabled
        }
    }

    public func execute(_ event: GestureEvent, buttonID: String? = nil) {
        queue.async { [weak self] in
            self?.executeOnQueue(event, buttonID: buttonID)
        }
    }

    public func execute(shortcut: Shortcut) {
        queue.async { [weak self] in
            guard let self, self.enabled else { return }
            AppLog.gesture.info("Execute shortcut \(shortcut.displayName, privacy: .public)")
            self.post(shortcut)
        }
    }

    private func executeOnQueue(_ event: GestureEvent, buttonID: String?) {
        guard enabled, let shortcut = config.shortcut(for: event, buttonID: buttonID) else { return }
        let button = buttonID ?? "gesture"
        AppLog.gesture.info(
            "Execute \(button, privacy: .public) \(event.rawValue, privacy: .public) -> \(shortcut.displayName, privacy: .public)"
        )
        post(shortcut)
    }

    private func post(_ shortcut: Shortcut) {
        for action in ShortcutPostPlan(shortcut: shortcut).actions {
            switch action {
            case let .key(code, down, flags):
                postKey(code, down: down, flags: flags)
            case let .pause(duration):
                Thread.sleep(forTimeInterval: duration)
            case let .unsupportedKey(key):
                AppLog.gesture.error("Unsupported shortcut key: \(key, privacy: .public)")
            }
        }
    }

    private func postKey(_ keyCode: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: down) else {
            return
        }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.userData)
        event.post(tap: .cgSessionEventTap)
    }
}
