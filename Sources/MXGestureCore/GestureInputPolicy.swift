import Foundation

public struct GestureInputPolicy: Equatable {
    public enum Mode: Equatable {
        case disabled
        case eventTapFallback
        case hidButtonOnly
        case hidRawXY
        case hidRawXYWithMovementFallback
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
        isHolding: Bool,
        rawXYFallbackActive: Bool = false
    ) {
        self.isHolding = isHolding

        guard isEnabled else {
            mode = .disabled
            return
        }

        if hidStatus.gestureConfigured {
            if hidStatus.rawXYEnabled {
                mode = rawXYFallbackActive ? .hidRawXYWithMovementFallback : .hidRawXY
            } else {
                mode = .hidButtonOnly
            }
        } else if hidStatus.connected {
            // Device is present but we couldn't program it (unknown firmware,
            // permission glitch, etc.). Fallback can still be useful.
            mode = .eventTapFallback
        } else {
            // No supported device present. Stay completely passive — don't
            // touch input. This prevents stealing buttons from other devices
            // and the cascade of failures that follows.
            mode = .disabled
        }
    }

    public var usesButtonFallback: Bool {
        mode == .eventTapFallback
    }

    public var capturesMovement: Bool {
        mode != .disabled && isHolding
    }

    public var usesMovementFallback: Bool {
        isHolding && (
            mode == .eventTapFallback ||
            mode == .hidButtonOnly ||
            mode == .hidRawXYWithMovementFallback
        )
    }

    public var blocksMovement: Bool {
        isHolding && (mode == .hidRawXY || mode == .hidRawXYWithMovementFallback)
    }
}
