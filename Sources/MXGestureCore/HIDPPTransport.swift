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

extension HIDPPTransport {
    func featureIndex(of featureID: UInt16, deviceIndex: UInt8) -> UInt8? {
        let response = request(
            deviceIndex: deviceIndex,
            featureIndex: ReprogControls.rootFeatureIndex,
            function: 0,
            params: [UInt8(featureID >> 8), UInt8(featureID & 0xFF), 0]
        )
        guard let index = response?.params.first, index != 0 else { return nil }
        return index
    }

    func firstFeature(_ featureID: UInt16) -> (deviceIndex: UInt8, featureIndex: UInt8)? {
        for index in ReprogControls.candidateDeviceIndices {
            if let featureIndex = featureIndex(of: featureID, deviceIndex: index) {
                return (index, featureIndex)
            }
        }
        return nil
    }
}
