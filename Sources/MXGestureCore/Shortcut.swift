import CoreGraphics
import Foundation

public struct Shortcut: Codable, Equatable {
    public var keys: [String]

    public init(keys: [String]) {
        self.keys = keys.map(Self.normalize).filter { !$0.isEmpty }
    }

    public init(text: String) {
        self.init(keys: text.split(separator: "+").map(String.init))
    }

    public var displayName: String {
        keys.joined(separator: "+")
    }

    public var isValid: Bool {
        let nonModifiers = keys.filter { !ShortcutKeyMap.isModifier($0) }
        return nonModifiers.count == 1 && ShortcutKeyMap.keyCode(for: nonModifiers[0]) != nil
    }

    private static func normalize(_ key: String) -> String {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "control": return "ctrl"
        case "command": return "cmd"
        case "option": return "alt"
        default: return value
        }
    }
}

public enum ShortcutKeyMap {
    public static func keyCode(for key: String) -> CGKeyCode? {
        codes[key.lowercased()]
    }

    public static func flags(for keys: [String]) -> CGEventFlags {
        keys.reduce([]) { flags, key in
            switch key.lowercased() {
            case "cmd", "command": return flags.union(.maskCommand)
            case "shift": return flags.union(.maskShift)
            case "ctrl", "control": return flags.union(.maskControl)
            case "alt", "option": return flags.union(.maskAlternate)
            case "fn", "function": return flags.union(.maskSecondaryFn)
            default: return flags
            }
        }
    }

    /// Flags macOS puts on a real press of `key` regardless of which modifiers
    /// the user asked for.
    ///
    /// Arrow keys are reported as function keys, and WindowServer refuses to
    /// match a symbolic hotkey — Mission Control's ⌃← / ⌃→ among them — unless
    /// `.maskSecondaryFn` is set. Sending plain `.maskControl` still delivers
    /// the key to the focused app, so the shortcut looks like it fired while no
    /// space ever moves. `.maskNumericPad` is not needed for the match but a
    /// hardware arrow key carries it, so include it to keep the synthesized
    /// event indistinguishable from the real one.
    public static func implicitFlags(for key: String) -> CGEventFlags {
        switch key.lowercased() {
        case "left", "right", "up", "down": return [.maskSecondaryFn, .maskNumericPad]
        default: return []
        }
    }

    public static func isModifier(_ key: String) -> Bool {
        ["cmd", "command", "shift", "ctrl", "control", "alt", "option", "fn", "function"]
            .contains(key.lowercased())
    }

    public static func modifierKeyCode(for key: String) -> CGKeyCode? {
        switch key.lowercased() {
        case "cmd", "command": return 55
        case "shift": return 56
        case "ctrl", "control": return 59
        case "alt", "option": return 58
        default: return nil
        }
    }

    private static let codes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
        "enter": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49,
        "`": 50, "delete": 51, "escape": 53, "esc": 53, "left": 123,
        "right": 124, "down": 125, "up": 126
    ]
}
