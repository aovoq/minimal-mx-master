import Foundation

public enum GestureEvent: String, CaseIterable, Codable, Equatable {
    case click
    case up
    case down
    case left
    case right
}

public enum HIDGestureSignal: Equatable {
    case buttonDown(cid: UInt16)
    case buttonUp(cid: UInt16)
    case rawXY(dx: Int, dy: Int)

    /// Event-tap fallback has no HID++ CID. Runtime maps this to the first
    /// button whose action is Gesture.
    public static let unknownCID: UInt16 = 0
}