import CoreGraphics

extension CGEventType {
    var isTapDisabledNotification: Bool {
        self == .tapDisabledByTimeout || self == .tapDisabledByUserInput
    }

    var isOtherMouseButtonEvent: Bool {
        self == .otherMouseDown || self == .otherMouseUp
    }

    var hidButtonSignal: HIDGestureSignal? {
        switch self {
        case .otherMouseDown:
            return .buttonDown
        case .otherMouseUp:
            return .buttonUp
        default:
            return nil
        }
    }
}

extension CGEvent {
    var isMXGestureSyntheticEvent: Bool {
        getIntegerValueField(.eventSourceUserData) == SyntheticEventMarker.userData
    }

    var otherMouseButtonNumber: Int {
        Int(getIntegerValueField(.mouseEventButtonNumber))
    }

    var mouseDelta: (dx: Int, dy: Int) {
        (
            dx: Int(getIntegerValueField(.mouseEventDeltaX)),
            dy: Int(getIntegerValueField(.mouseEventDeltaY))
        )
    }
}
