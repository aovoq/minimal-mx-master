import Foundation
import IOKit.hid

public final class HIDPPClient {
    public var onGestureSignal: ((HIDGestureSignal) -> Void)?

    private let broker: HIDPPRequestBroker
    private let reprogControls: ReprogControlsFeature
    private let wheelFeatures: WheelFeatures

    public init(device: IOHIDDevice) {
        self.broker = HIDPPRequestBroker(device: device)
        self.reprogControls = ReprogControlsFeature(transport: broker)
        self.wheelFeatures = WheelFeatures(transport: broker)
    }

    public var rawXYEnabled: Bool {
        reprogControls.rawXYEnabled
    }

    public func configureGesture(
        selectedCIDs: [UInt16] = [],
        gestureCIDs: [UInt16]? = nil,
        autoSelectIfEmpty: Bool = true
    ) -> ReprogConfiguration? {
        reprogControls.configureGesture(
            selectedCIDs: selectedCIDs,
            gestureCIDs: gestureCIDs,
            autoSelectIfEmpty: autoSelectIfEmpty
        )
    }

    @discardableResult
    public func configureWheels(_ settings: WheelSettings) -> WheelApplyResult {
        wheelFeatures.apply(settings)
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