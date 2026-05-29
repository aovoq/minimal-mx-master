import Foundation

enum SystemEventsShortcutExecutor {
    static func execute(_ shortcut: Shortcut) -> Bool {
        guard let keyCode = appleScriptKeyCode(for: shortcut) else { return false }
        let source = """
        tell application id "com.apple.systemevents" to key code \(keyCode) using control down
        """

        // NSAppleScript is documented to require the main thread. Running it
        // from a background queue can deadlock against the automation-
        // permission prompt and freeze the executor queue, which then queues
        // up gestures and replays them in a burst when (if) it unblocks —
        // exactly the failure mode that locks the user out of input.
        let block = { () -> Bool in
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

        if Thread.isMainThread {
            return block()
        }
        var result = false
        DispatchQueue.main.sync { result = block() }
        return result
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
