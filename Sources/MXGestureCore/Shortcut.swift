import CoreGraphics
import Foundation

public struct Shortcut: Codable, Equatable {
    public var keys: [String]

    public init(keys: [String]) {
        let normalized = keys.map(Self.normalize).filter { !$0.isEmpty }
        let modifiers = Self.canonicalModifierOrder.filter { normalized.contains($0) }
        let rest = normalized.filter { !ShortcutKeyMap.isModifier($0) }
        self.keys = modifiers + rest
    }

    public init(text: String) {
        self.init(keys: text.split(separator: "+").map(String.init))
    }

    public init?(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let key = ShortcutKeyMap.keyName(for: keyCode) else { return nil }
        guard !ShortcutKeyMap.isModifier(key) else { return nil }
        let implicit = ShortcutKeyMap.implicitFlags(for: key)
        var names: [String] = []
        if flags.contains(.maskControl) { names.append("ctrl") }
        if flags.contains(.maskAlternate) { names.append("alt") }
        if flags.contains(.maskShift) { names.append("shift") }
        if flags.contains(.maskCommand) { names.append("cmd") }
        if flags.contains(.maskSecondaryFn), !implicit.contains(.maskSecondaryFn) {
            names.append("fn")
        }
        names.append(key)
        self.init(keys: names)
    }

    public var displayName: String {
        keys.joined(separator: "+")
    }

    public var glyphDisplay: String {
        keys.map(Self.glyph(for:)).joined()
    }

    public var isValid: Bool {
        let nonModifiers = keys.filter { !ShortcutKeyMap.isModifier($0) }
        return nonModifiers.count == 1 && ShortcutKeyMap.keyCode(for: nonModifiers[0]) != nil
    }

    private enum CodingKeys: String, CodingKey {
        case keys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode([String].self, forKey: .keys)
        self.init(keys: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keys, forKey: .keys)
    }

    private static let canonicalModifierOrder = ["ctrl", "alt", "shift", "cmd", "fn"]

    private static func normalize(_ key: String) -> String {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "control": return "ctrl"
        case "command": return "cmd"
        case "option": return "alt"
        case "function": return "fn"
        default: return value
        }
    }

    public static func glyph(for key: String) -> String {
        switch key {
        case "ctrl": return "⌃"
        case "alt": return "⌥"
        case "shift": return "⇧"
        case "cmd": return "⌘"
        case "fn": return "fn"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        case "tab": return "⇥"
        case "return", "enter": return "↩"
        case "space": return "Space"
        case "delete": return "⌫"
        case "escape", "esc": return "⎋"
        default:
            return key.count == 1 ? key.uppercased() : key
        }
    }

    public static func modifierGlyphs(from flags: CGEventFlags) -> String {
        var names: [String] = []
        if flags.contains(.maskControl) { names.append("ctrl") }
        if flags.contains(.maskAlternate) { names.append("alt") }
        if flags.contains(.maskShift) { names.append("shift") }
        if flags.contains(.maskCommand) { names.append("cmd") }
        if flags.contains(.maskSecondaryFn) { names.append("fn") }
        return names.map(glyph(for:)).joined()
    }
}

public enum ShortcutRecordResult: Equatable {
    case captured(Shortcut)
    case clear
    case cancel
    case ignore
}

extension Shortcut {
    public static func record(keyCode: CGKeyCode, flags: CGEventFlags, isRepeat: Bool = false) -> ShortcutRecordResult {
        if isRepeat { return .ignore }
        if keyCode == 53 { return .cancel }
        if keyCode == 51 { return .clear }
        if ShortcutKeyMap.isModifierKeyCode(keyCode) { return .ignore }
        guard let shortcut = Shortcut(keyCode: keyCode, flags: flags), shortcut.isValid else {
            return .ignore
        }
        return .captured(shortcut)
    }
}

public enum ShortcutFieldIssue: Equatable {
    case empty
    case invalid
    case duplicate

    public var message: String {
        switch self {
        case .empty: return "Empty"
        case .invalid: return "Invalid"
        case .duplicate: return "Duplicate"
        }
    }

    public static func evaluate(_ shortcut: Shortcut, others: [Shortcut]) -> ShortcutFieldIssue? {
        if shortcut.keys.isEmpty { return .empty }
        if !shortcut.isValid { return .invalid }
        if others.contains(where: { $0.isValid && $0 == shortcut }) { return .duplicate }
        return nil
    }
}

public enum ShortcutKeyMap {
    public static func keyCode(for key: String) -> CGKeyCode? {
        codes[key.lowercased()]
    }

    public static func keyName(for code: CGKeyCode) -> String? {
        names[code]
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

    public static func isModifierKeyCode(_ code: CGKeyCode) -> Bool {
        [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(code)
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

    private static let names: [CGKeyCode: String] = {
        var result: [CGKeyCode: String] = [:]
        for (name, code) in codes {
            if result[code] == nil {
                result[code] = name
            }
        }
        result[36] = "return"
        result[53] = "escape"
        return result
    }()
}
