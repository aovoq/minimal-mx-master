import CoreGraphics
import Foundation

struct ShortcutPostPlan {
    enum Action: Equatable {
        case key(CGKeyCode, down: Bool, flags: CGEventFlags)
        case pause(TimeInterval)
        case unsupportedKey(String)
    }

    static let keyPressInterval: TimeInterval = 0.01

    let actions: [Action]

    init(shortcut: Shortcut) {
        let modifiers = shortcut.keys.filter { ShortcutKeyMap.isModifier($0) }
        let modifierCodes = modifiers.compactMap { ShortcutKeyMap.modifierKeyCode(for: $0) }
        let flags = ShortcutKeyMap.flags(for: modifiers)
        let keys = shortcut.keys.filter { !ShortcutKeyMap.isModifier($0) }

        var actions: [Action] = modifierCodes.map { .key($0, down: true, flags: flags) }
        if !modifierCodes.isEmpty {
            actions.append(.pause(Self.keyPressInterval))
        }

        for key in keys {
            guard let keyCode = ShortcutKeyMap.keyCode(for: key) else {
                actions.append(.unsupportedKey(key))
                continue
            }
            // Only the key itself gets the implicit flags; a real ⌃← reports
            // the fn bit on the arrow event, not on the control press.
            let keyFlags = flags.union(ShortcutKeyMap.implicitFlags(for: key))
            actions.append(.key(keyCode, down: true, flags: keyFlags))
            actions.append(.pause(Self.keyPressInterval))
            actions.append(.key(keyCode, down: false, flags: keyFlags))
        }

        actions.append(contentsOf: modifierCodes.reversed().map { .key($0, down: false, flags: []) })
        self.actions = actions
    }
}
