import CoreGraphics
import XCTest
@testable import MXGestureCore

final class ShortcutPostPlanTests: XCTestCase {
    func testShortcutPlanPostsModifiersAroundKeyPress() {
        let plan = ShortcutPostPlan(shortcut: Shortcut(keys: ["ctrl", "left"]))
        let flags = ShortcutKeyMap.flags(for: ["ctrl"])
        let arrowFlags = flags.union([.maskSecondaryFn, .maskNumericPad])

        XCTAssertEqual(plan.actions, [
            .key(59, down: true, flags: flags),
            .pause(ShortcutPostPlan.keyPressInterval),
            .key(123, down: true, flags: arrowFlags),
            .pause(ShortcutPostPlan.keyPressInterval),
            .key(123, down: false, flags: arrowFlags),
            .key(59, down: false, flags: [])
        ])
    }

    /// WindowServer only matches a symbolic hotkey such as Mission Control's
    /// ⌃← / ⌃→ when the arrow event carries the fn bit. Dropping it leaves the
    /// key still being delivered to the focused app, so the regression is
    /// invisible in logs — the executor reports success and nothing moves.
    func testArrowKeysCarryTheFlagsMacOSPutsOnARealArrowPress() {
        for key in ["left", "right", "up", "down"] {
            XCTAssertEqual(
                ShortcutKeyMap.implicitFlags(for: key),
                [.maskSecondaryFn, .maskNumericPad],
                "\(key) must look like a hardware arrow press"
            )
        }
    }

    func testNonArrowKeysGetNoImplicitFlags() {
        for key in ["a", "space", "return", "escape", "1"] {
            XCTAssertEqual(ShortcutKeyMap.implicitFlags(for: key), [], key)
        }
    }

    func testModifierPressItselfDoesNotCarryTheArrowFlags() {
        let plan = ShortcutPostPlan(shortcut: Shortcut(keys: ["ctrl", "right"]))
        let controlDown = plan.actions.first

        XCTAssertEqual(controlDown, .key(59, down: true, flags: ShortcutKeyMap.flags(for: ["ctrl"])))
    }

    func testShortcutPlanDoesNotAddModifierPauseWhenThereAreNoModifiers() {
        let plan = ShortcutPostPlan(shortcut: Shortcut(keys: ["a"]))

        XCTAssertEqual(plan.actions, [
            .key(0, down: true, flags: []),
            .pause(ShortcutPostPlan.keyPressInterval),
            .key(0, down: false, flags: [])
        ])
    }

    func testShortcutPlanKeepsUnsupportedKeysInOrderAndStillReleasesModifiers() {
        let plan = ShortcutPostPlan(shortcut: Shortcut(keys: ["ctrl", "missing-key"]))
        let flags = ShortcutKeyMap.flags(for: ["ctrl"])

        XCTAssertEqual(plan.actions, [
            .key(59, down: true, flags: flags),
            .pause(ShortcutPostPlan.keyPressInterval),
            .unsupportedKey("missing-key"),
            .key(59, down: false, flags: [])
        ])
    }
}
