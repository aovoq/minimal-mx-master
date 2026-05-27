import Foundation

public enum GestureEvent: String, CaseIterable, Codable, Equatable {
    case click
    case up
    case down
    case left
    case right
}

public enum HIDGestureSignal: Equatable {
    case buttonDown
    case buttonUp
    case rawXY(dx: Int, dy: Int)
}
