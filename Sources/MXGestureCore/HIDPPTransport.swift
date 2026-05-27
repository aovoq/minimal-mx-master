import Foundation

struct HIDPPRequestKey: Hashable {
    var deviceIndex: UInt8
    var featureIndex: UInt8
    var function: UInt8
}

protocol HIDPPTransport {
    func request(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> HIDPPMessage?

    @discardableResult
    func send(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8]
    ) -> Bool
}
