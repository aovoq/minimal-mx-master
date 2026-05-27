import Foundation

enum SystemEventsShortcutExecutor {
    static func execute(_ shortcut: Shortcut) -> Bool {
        guard let keyCode = appleScriptKeyCode(for: shortcut) else { return false }
        let source = """
        tell application id "com.apple.systemevents" to key code \(keyCode) using control down
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        _ = script.executeAndReturnError(&error)

        if let error {
            AppLog.gesture.error("System Events shortcut failed: \(String(describing: error), privacy: .public)")
        }
        let succeeded = error == nil
        if succeeded {
            AppLog.gesture.info("System Events shortcut executed keyCode \(keyCode)")
        }
        return succeeded
    }

    private static func appleScriptKeyCode(for shortcut: Shortcut) -> Int? {
        let modifiers = Set(shortcut.keys.filter { ShortcutKeyMap.isModifier($0) }.map(normalizedModifier))
        let keys = shortcut.keys.filter { !ShortcutKeyMap.isModifier($0) }

        guard modifiers == ["ctrl"], keys.count == 1 else { return nil }
        switch keys[0] {
        case "left": return 123
        case "right": return 124
        case "down": return 125
        case "up": return 126
        default: return nil
        }
    }

    private static func normalizedModifier(_ key: String) -> String {
        key == "control" ? "ctrl" : key
    }
}
