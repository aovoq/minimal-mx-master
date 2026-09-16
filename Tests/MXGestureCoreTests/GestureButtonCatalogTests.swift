import XCTest
@testable import MXGestureCore

final class GestureButtonCatalogTests: XCTestCase {
    func testEmptySelectionMeansDedicatedGestureButton() {
        let gesture = GestureButtonCatalog.options.first { $0.id == "gesture" }!
        let back = GestureButtonCatalog.options.first { $0.id == "back" }!

        XCTAssertTrue(GestureButtonCatalog.isSelected(gesture, cids: []))
        XCTAssertFalse(GestureButtonCatalog.isSelected(back, cids: []))
        XCTAssertEqual(GestureButtonCatalog.summary(cids: []), "Gesture")
    }

    func testCatalogIncludesLeftAndRightInNamedOrder() {
        XCTAssertEqual(
            GestureButtonCatalog.options.map(\.id),
            ["gesture", "back", "forward", "left", "middle", "right", "smartShift"]
        )
        XCTAssertEqual(GestureButtonCatalog.option(id: "left")?.cids, [0x0050])
        XCTAssertEqual(GestureButtonCatalog.option(id: "right")?.cids, [0x0051])
    }

    func testSelectedIDsExpandToKnownCIDs() {
        XCTAssertEqual(
            GestureButtonCatalog.cids(fromSelectedIDs: ["gesture", "back"]),
            ReprogControls.preferredGestureCIDs + [0x0053]
        )
    }

    func testSummaryListsCheckedButtons() {
        XCTAssertEqual(
            GestureButtonCatalog.summary(cids: [0x00C3, 0x0053, 0x0056]),
            "Gesture, Back, Forward"
        )
    }

    func testSummaryListsAssignedActions() {
        var config = AppConfig()
        config.buttonAssignments = [
            "gesture": .gesture(),
            "back": ButtonAssignment(action: .shortcut, shortcut: Shortcut(keys: ["cmd", "["]))
        ]

        XCTAssertEqual(
            GestureButtonCatalog.summary(config: config),
            "Gesture: Gesture, Back: Shortcut"
        )
    }
}