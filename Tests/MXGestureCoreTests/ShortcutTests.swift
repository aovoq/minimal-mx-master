import CoreGraphics
import XCTest
@testable import MXGestureCore

final class ShortcutTests: XCTestCase {
    func testGlyphDisplayUsesMacModifierSymbols() {
        XCTAssertEqual(Shortcut(keys: ["ctrl", "up"]).glyphDisplay, "⌃↑")
        XCTAssertEqual(Shortcut(keys: ["cmd", "["]).glyphDisplay, "⌘[")
        XCTAssertEqual(Shortcut(keys: ["cmd", "shift", "tab"]).glyphDisplay, "⇧⌘⇥")
        XCTAssertEqual(Shortcut(keys: ["alt", "space"]).glyphDisplay, "⌥Space")
        XCTAssertEqual(Shortcut(keys: []).glyphDisplay, "")
    }

    func testInitCanonicalizesModifierOrder() {
        XCTAssertEqual(Shortcut(keys: ["up", "ctrl"]), Shortcut(keys: ["ctrl", "up"]))
        XCTAssertEqual(Shortcut(text: "cmd+shift+tab").keys, ["shift", "cmd", "tab"])
    }

    func testRecordFromKeyCodeAndFlags() {
        let arrow = Shortcut.record(
            keyCode: 126,
            flags: [.maskControl, .maskSecondaryFn, .maskNumericPad]
        )
        XCTAssertEqual(arrow, .captured(Shortcut(keys: ["ctrl", "up"])))

        let commandLeftBracket = Shortcut.record(keyCode: 33, flags: [.maskCommand])
        XCTAssertEqual(commandLeftBracket, .captured(Shortcut(keys: ["cmd", "["])))
    }

    func testRecordIgnoresModifiersAndRepeats() {
        XCTAssertEqual(Shortcut.record(keyCode: 59, flags: [.maskControl]), .ignore)
        XCTAssertEqual(Shortcut.record(keyCode: 0, flags: [], isRepeat: true), .ignore)
    }

    func testRecordBackspaceClearsAndEscapeCancels() {
        XCTAssertEqual(Shortcut.record(keyCode: 51, flags: []), .clear)
        XCTAssertEqual(Shortcut.record(keyCode: 53, flags: []), .cancel)
        XCTAssertEqual(Shortcut.record(keyCode: 51, flags: [.maskCommand]), .clear)
    }

    func testArrowRecordingDoesNotStoreImplicitFn() {
        let shortcut = Shortcut(keyCode: 123, flags: [.maskControl, .maskSecondaryFn, .maskNumericPad])
        XCTAssertEqual(shortcut, Shortcut(keys: ["ctrl", "left"]))
        XCTAssertFalse(shortcut?.keys.contains("fn") ?? true)
    }

    func testFieldIssueEmptyInvalidDuplicate() {
        let empty = Shortcut(keys: [])
        let valid = Shortcut(keys: ["ctrl", "up"])
        let invalid = Shortcut(keys: ["ctrl"])
        let other = Shortcut(keys: ["cmd", "tab"])

        XCTAssertEqual(ShortcutFieldIssue.evaluate(empty, others: [valid]), .empty)
        XCTAssertEqual(ShortcutFieldIssue.evaluate(invalid, others: []), .invalid)
        XCTAssertEqual(ShortcutFieldIssue.evaluate(valid, others: [valid, other]), .duplicate)
        XCTAssertNil(ShortcutFieldIssue.evaluate(valid, others: [other, empty]))
    }
}
