import Foundation

struct EventDropWatchdog {
    enum Decision: Equatable {
        case drop
        case releaseAndPassThrough(duration: TimeInterval)
        case passThrough
    }

    let maxDropDuration: TimeInterval
    private var dropStartedAt: TimeInterval?
    private(set) var isPanicLatched = false

    init(maxDropDuration: TimeInterval) {
        self.maxDropDuration = maxDropDuration
    }

    mutating func handleDroppedMovement(at now: TimeInterval) -> Decision {
        guard !isPanicLatched else { return .passThrough }

        if dropStartedAt == nil {
            dropStartedAt = now
        }

        guard let started = dropStartedAt else { return .drop }
        let duration = now - started
        guard duration > maxDropDuration else { return .drop }
        return .releaseAndPassThrough(duration: duration)
    }

    @discardableResult
    mutating func trip() -> Bool {
        dropStartedAt = nil
        guard !isPanicLatched else { return false }
        isPanicLatched = true
        return true
    }

    mutating func reset() {
        dropStartedAt = nil
        isPanicLatched = false
    }
}
