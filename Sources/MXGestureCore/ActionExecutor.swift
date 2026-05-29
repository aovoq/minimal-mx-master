import CoreGraphics
import Foundation

public final class ActionExecutor {
    public static let syntheticMarker: Int64 = 0x4D584742

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
        let modifiers = shortcut.keys.filter { ShortcutKeyMap.isModifier($0) }
        let modifierCodes = modifiers.compactMap { ShortcutKeyMap.modifierKeyCode(for: $0) }
        let flags = ShortcutKeyMap.flags(for: modifiers)
        let keys = shortcut.keys.filter { !ShortcutKeyMap.isModifier($0) }

        for code in modifierCodes {
            postKey(code, down: true, flags: flags)
        }
        if !modifierCodes.isEmpty {
            Thread.sleep(forTimeInterval: 0.01)
        }

        for key in keys {
            guard let keyCode = ShortcutKeyMap.keyCode(for: key) else {
                AppLog.gesture.error("Unsupported shortcut key: \(key, privacy: .public)")
                continue
            }
            postKey(keyCode, down: true, flags: flags)
            Thread.sleep(forTimeInterval: 0.01)
            postKey(keyCode, down: false, flags: flags)
        }

        for code in modifierCodes.reversed() {
            postKey(code, down: false, flags: [])
        }
    }

    private func postKey(_ keyCode: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: down) else {
            return
        }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        event.post(tap: .cgSessionEventTap)
    }
}
