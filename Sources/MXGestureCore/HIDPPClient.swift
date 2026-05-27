import Foundation
import IOKit.hid

public final class HIDPPClient {
    public var onGestureSignal: ((HIDGestureSignal) -> Void)?

    private let broker: HIDPPRequestBroker
    private let reprogControls: ReprogControlsFeature

    public init(device: IOHIDDevice) {
        self.broker = HIDPPRequestBroker(device: device)
        self.reprogControls = ReprogControlsFeature(transport: broker)
    }

    public var rawXYEnabled: Bool {
        reprogControls.rawXYEnabled
    }

    public func configureGesture() -> ReprogConfiguration? {
        reprogControls.configureGesture()
    }

    public func restoreDefaultReporting() {
        reprogControls.restoreDefaultReporting()
    }

    public func receive(reportID: UInt8, bytes: [UInt8]) {
        guard let message = HIDPPMessage(reportID: reportID, bytes: bytes) else { return }
        if broker.resolve(message) { return }
        if let signal = reprogControls.handleEvent(message) {
            onGestureSignal?(signal)
        }
    }
}
