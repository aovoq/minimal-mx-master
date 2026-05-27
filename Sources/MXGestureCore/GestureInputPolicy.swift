import Foundation

public struct GestureInputPolicy: Equatable {
    public enum Mode: Equatable {
        case disabled
        case eventTapFallback
        case hidButtonOnly
        case hidRawXY
    }

    public var mode: Mode
    public var isHolding: Bool

    public init(mode: Mode, isHolding: Bool) {
        self.mode = mode
        self.isHolding = isHolding
    }

    public init(
        isEnabled: Bool,
        hidStatus: HIDDeviceStatus,
        isHolding: Bool
    ) {
        self.isHolding = isHolding

        guard isEnabled else {
            mode = .disabled
            return
        }

        if hidStatus.gestureConfigured {
            mode = hidStatus.rawXYEnabled ? .hidRawXY : .hidButtonOnly
        } else {
            mode = .eventTapFallback
        }
    }

    public var usesButtonFallback: Bool {
        mode == .eventTapFallback
    }

    public var capturesMovement: Bool {
        mode != .disabled && isHolding
    }

    public var usesMovementFallback: Bool {
        isHolding && (mode == .eventTapFallback || mode == .hidButtonOnly)
    }

    public var blocksMovement: Bool {
        isHolding && mode == .hidRawXY
    }
}
