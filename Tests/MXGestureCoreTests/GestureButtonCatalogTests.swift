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
}
