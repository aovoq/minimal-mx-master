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
        SystemEventsShortcutExecutor.prepare()
    }

    public func update(config: AppConfig) {
        queue.async { [weak self] in
            self?.config = config
            self?.enabled = config.enabled
        }
    }

    public func execute(_ event: GestureEvent) {
        queue.async { [weak self] in
            self?.executeOnQueue(event)
        }
    }

    private func executeOnQueue(_ event: GestureEvent) {
        guard enabled, let shortcut = config.shortcut(for: event) else { return }
        AppLog.gesture.info("Execute \(event.rawValue, privacy: .public) -> \(shortcut.displayName, privacy: .public)")
        if SystemEventsShortcutExecutor.execute(shortcut) {
            return
        }
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
