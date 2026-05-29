import Foundation

public struct GestureRuntimeState {
    public enum SignalEffect: Equatable {
        case none
        case beginHold
        case endHold
    }

    public static let defaultRawXYFallbackDelay: TimeInterval = 0.15

    public private(set) var hidStatus: HIDDeviceStatus
    private var lastRawXYSignalAt: TimeInterval?
    private let rawXYFallbackDelay: TimeInterval

    public init(
        hidStatus: HIDDeviceStatus = .notConnected,
        rawXYFallbackDelay: TimeInterval = Self.defaultRawXYFallbackDelay
    ) {
        self.hidStatus = hidStatus
        self.rawXYFallbackDelay = rawXYFallbackDelay
    }

    public mutating func update(status: HIDDeviceStatus) {
        hidStatus = status
    }

    public mutating func resetStatus() {
        hidStatus = .notConnected
        lastRawXYSignalAt = nil
    }

    public mutating func observe(_ signal: HIDGestureSignal, at now: TimeInterval) -> SignalEffect {
        switch signal {
        case .buttonDown:
            lastRawXYSignalAt = nil
            return .beginHold
        case .buttonUp:
            lastRawXYSignalAt = nil
            return .endHold
        case .rawXY:
            lastRawXYSignalAt = now
            return .none
        }
    }

    public func inputPolicy(isEnabled: Bool, isHolding: Bool, now: TimeInterval) -> GestureInputPolicy {
        GestureInputPolicy(
            isEnabled: isEnabled,
            hidStatus: hidStatus,
            isHolding: isHolding,
            rawXYFallbackActive: rawXYFallbackActive(isHolding: isHolding, now: now)
        )
    }

    public func rawXYFallbackActive(isHolding: Bool, now: TimeInterval) -> Bool {
        guard hidStatus.gestureConfigured, hidStatus.rawXYEnabled, isHolding else {
            return false
        }
        guard let lastRawXYSignalAt else { return true }
        return now - lastRawXYSignalAt > rawXYFallbackDelay
    }
}
