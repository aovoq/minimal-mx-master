import XCTest
@testable import MXGestureCore

final class AppConfigTests: XCTestCase {
    func testLegacyPayloadWithoutGestureButtonsDecodesAsAuto() throws {
        let json = """
        {
          "enabled": true,
          "mappings": {
            "click": { "keys": ["ctrl", "up"] }
          },
          "gesture": {
            "threshold": 50,
            "deadzone": 40,
            "timeoutMs": 3000,
            "cooldownMs": 500,
            "initialIgnoreMs": 30
          }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: json)
        XCTAssertEqual(config.gestureButtonCIDs, [])
        XCTAssertEqual(config.enabled, true)
        XCTAssertEqual(config.shortcut(for: .click), Shortcut(keys: ["ctrl", "up"]))
        XCTAssertEqual(config.assignment(forButtonID: "gesture").action, .gesture)
        XCTAssertEqual(config.assignment(forButtonID: "back").action, .default)
        XCTAssertEqual(config.gestureCIDs, ReprogControls.preferredGestureCIDs)
    }

    func testGestureButtonCIDsRoundTrip() throws {
        let original = AppConfig(gestureButtonCIDs: [0x00C3, 0x0053])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.assignment(forButtonID: "gesture").action, .gesture)
        XCTAssertEqual(decoded.assignment(forButtonID: "back").action, .gesture)
        XCTAssertEqual(decoded.gestureCIDs, ReprogControls.preferredGestureCIDs + [0x0053])
    }

    func testButtonAssignmentsKeepIndependentGestureMaps() throws {
        var original = AppConfig()
        original.buttonAssignments = [
            "gesture": .gesture(mappings: [
                GestureEvent.click.rawValue: Shortcut(keys: ["ctrl", "up"]),
                GestureEvent.up.rawValue: Shortcut(keys: ["cmd", "tab"]),
                GestureEvent.down.rawValue: Shortcut(keys: ["ctrl", "down"]),
                GestureEvent.left.rawValue: Shortcut(keys: ["ctrl", "right"]),
                GestureEvent.right.rawValue: Shortcut(keys: ["ctrl", "left"])
            ]),
            "back": .gesture(mappings: [
                GestureEvent.click.rawValue: Shortcut(keys: ["cmd", "["]),
                GestureEvent.up.rawValue: Shortcut(keys: ["cmd", "up"]),
                GestureEvent.down.rawValue: Shortcut(keys: ["cmd", "down"]),
                GestureEvent.left.rawValue: Shortcut(keys: ["cmd", "left"]),
                GestureEvent.right.rawValue: Shortcut(keys: ["cmd", "right"])
            ]),
            "smartShift": ButtonAssignment(action: .shortcut, shortcut: Shortcut(keys: ["cmd", "tab"]))
        ]
        original.wheels = WheelSettings(invertMain: true, invertThumb: true)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(decoded.shortcut(for: .click, buttonID: "gesture"), Shortcut(keys: ["ctrl", "up"]))
        XCTAssertEqual(decoded.shortcut(for: .click, buttonID: "back"), Shortcut(keys: ["cmd", "["]))
        XCTAssertEqual(decoded.shortcut(for: .left, buttonID: "back"), Shortcut(keys: ["cmd", "left"]))
        XCTAssertEqual(decoded.clickShortcut(forButtonID: "smartShift"), Shortcut(keys: ["cmd", "tab"]))
        XCTAssertEqual(decoded.assignment(forButtonID: "left").action, .default)
        XCTAssertTrue(decoded.wheels.invertMain)
        XCTAssertTrue(decoded.wheels.invertThumb)
        XCTAssertEqual(decoded.divertCIDs, ReprogControls.preferredGestureCIDs + [0x0053, 0x00C4])
        XCTAssertEqual(decoded.shortcutCIDs, [0x00C4])
    }

    func testGestureButtonDoesNotInheritMissingEventsFromGlobalMap() {
        var config = AppConfig()
        config.buttonAssignments = [
            "gesture": .gesture(mappings: AppConfig.defaultMappings),
            "back": .gesture(mappings: [
                GestureEvent.click.rawValue: Shortcut(keys: ["cmd", "["])
            ]),
            "smartShift": .gesture(mappings: [
                GestureEvent.up.rawValue: Shortcut(keys: ["cmd", "shift", "tab"]),
                GestureEvent.down.rawValue: Shortcut(keys: ["ctrl", "down"])
            ])
        ]

        XCTAssertEqual(config.shortcut(for: .click, buttonID: "back"), Shortcut(keys: ["cmd", "["]))
        XCTAssertNil(config.shortcut(for: .up, buttonID: "back"))
        XCTAssertEqual(config.shortcut(for: .up, buttonID: "smartShift"), Shortcut(keys: ["cmd", "shift", "tab"]))
        XCTAssertNil(config.shortcut(for: .click, buttonID: "smartShift"))
        XCTAssertEqual(config.shortcut(for: .click, buttonID: "gesture"), Shortcut(keys: ["ctrl", "up"]))
    }

    func testAllDefaultButtonsDoNotDivert() {
        var config = AppConfig()
        config.buttonAssignments = Dictionary(
            uniqueKeysWithValues: GestureButtonCatalog.options.map {
                ($0.id, ButtonAssignment(action: .default))
            }
        )

        XCTAssertEqual(config.divertCIDs, [])
        XCTAssertEqual(config.gestureCIDs, [])
        XCTAssertEqual(config.gestureButtonIDs, [])
    }
}