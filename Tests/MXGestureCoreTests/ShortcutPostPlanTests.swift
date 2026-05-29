import CoreGraphics
import XCTest
@testable import MXGestureCore

final class ShortcutPostPlanTests: XCTestCase {
    func testShortcutPlanPostsModifiersAroundKeyPress() {
        let plan = ShortcutPostPlan(shortcut: Shortcut(keys: ["ctrl", "left"]))
        let flags = ShortcutKeyMap.flags(for: ["ctrl"])

        XCTAssertEqual(plan.actions, [
            .key(59, down: true, flags: flags),
            .pause(ShortcutPostPlan.keyPressInterval),
            .key(123, down: true, flags: flags),
            .pause(ShortcutPostPlan.keyPressInterval),
            .key(123, down: false, flags: flags),
            .key(59, down: false, flags: [])
        ])
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
