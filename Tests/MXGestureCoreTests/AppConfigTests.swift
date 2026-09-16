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
    }

    func testGestureButtonCIDsRoundTrip() throws {
        let original = AppConfig(gestureButtonCIDs: [0x00C3, 0x0053])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.gestureButtonCIDs, [0x00C3, 0x0053])
    }
}
