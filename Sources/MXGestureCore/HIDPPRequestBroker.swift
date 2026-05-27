import Foundation
import IOKit.hid

final class HIDPPRequestBroker: HIDPPTransport {
    private final class PendingRequest {
        let key: HIDPPRequestKey
        let semaphore = DispatchSemaphore(value: 0)
        var response: HIDPPMessage?

        init(key: HIDPPRequestKey) {
            self.key = key
        }
    }

    private let device: IOHIDDevice
    private let requestQueue = DispatchQueue(label: "dev.aovoq.MXGestureBar.HIDPPRequestBroker")
    private let lock = NSLock()
    private var pending: [HIDPPRequestKey: PendingRequest] = [:]

    init(device: IOHIDDevice) {
        self.device = device
    }

    func request(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> HIDPPMessage? {
        requestQueue.sync {
            requestOnQueue(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                function: function,
                params: params
            )
        }
    }

    private func requestOnQueue(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> HIDPPMessage? {
        let message = HIDPPMessage(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            function: function,
            params: params
        )
        let request = PendingRequest(key: message.requestKey)

        lock.withLock { pending[request.key] = request }
        defer { removePending(request) }

        let bytes = message.bytes
        let result = bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return kIOReturnBadArgument }
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(message.reportID),
                baseAddress,
                CFIndex(bytes.count)
            )
        }

        guard result == kIOReturnSuccess else {
            return nil
        }

        guard request.semaphore.wait(timeout: .now() + .milliseconds(350)) == .success else {
            return nil
        }
        return request.response
    }

    @discardableResult
    func send(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> Bool {
        requestQueue.sync {
            sendOnQueue(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                function: function,
                params: params
            )
        }
    }

    private func sendOnQueue(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> Bool {
        let message = HIDPPMessage(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            function: function,
            params: params
        )
        let bytes = message.bytes
        let result = bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return kIOReturnBadArgument }
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(message.reportID),
                baseAddress,
                CFIndex(bytes.count)
            )
        }
        return result == kIOReturnSuccess
    }

    func resolve(_ message: HIDPPMessage) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let request = pending.removeValue(forKey: message.requestKey) else { return false }
        request.response = message
        request.semaphore.signal()
        return true
    }

    private func removePending(_ request: PendingRequest) {
        lock.withLock {
            if pending[request.key] === request {
                pending.removeValue(forKey: request.key)
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
