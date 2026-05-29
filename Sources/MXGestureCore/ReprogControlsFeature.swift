import Foundation

final class ReprogControlsFeature {
    private let transport: HIDPPTransport
    private var configuration: ReprogConfiguration?
    private var selectedPressed = false

    init(transport: HIDPPTransport) {
        self.transport = transport
    }

    var rawXYEnabled: Bool {
        configuration?.rawXYEnabled ?? false
    }

    func configureGesture() -> ReprogConfiguration? {
        for index in ReprogControls.candidateDeviceIndices {
            guard let featureIndex = findFeature(deviceIndex: index) else { continue }
            AppLog.hid.info("Found REPROG_CONTROLS_V4 at index \(featureIndex) deviceIndex \(index)")
            let controls = readControls(deviceIndex: index, featureIndex: featureIndex)
            guard let control = ReprogControls.chooseGestureControl(from: controls) else { continue }
            AppLog.hid.info("Selected gesture CID 0x\(String(control.cid, radix: 16), privacy: .public)")

            if let configuration = configureReporting(
                control: control,
                rawXY: true,
                deviceIndex: index,
                featureIndex: featureIndex
            ) {
                AppLog.hid.info("Enabled RawXY divert for CID 0x\(String(control.cid, radix: 16), privacy: .public)")
                self.configuration = configuration
                return configuration
            }

            if let configuration = configureReporting(
                control: control,
                rawXY: false,
                deviceIndex: index,
                featureIndex: featureIndex
            ) {
                AppLog.hid.info("Enabled divert without RawXY for CID 0x\(String(control.cid, radix: 16), privacy: .public)")
                self.configuration = configuration
                return configuration
            }
        }

        return nil
    }

    func restoreDefaultReporting() {
        guard let configuration else { return }
        _ = transport.send(
            deviceIndex: configuration.deviceIndex,
            featureIndex: configuration.featureIndex,
            function: 3,
            params: ReprogControls.reportingParams(
                cid: configuration.control.cid,
                flags: ReprogControls.clearReportingFlags
            )
        )
        self.configuration = nil
        selectedPressed = false
    }

    func handleEvent(_ message: HIDPPMessage) -> HIDGestureSignal? {
        guard
            let configuration,
            message.deviceIndex == configuration.deviceIndex,
            message.featureIndex == configuration.featureIndex
        else { return nil }

        if message.function == 0 {
            let pressed = ReprogControls
                .pressedCIDs(from: message.params)
                .contains(configuration.control.cid)
            guard pressed != selectedPressed else { return nil }
            selectedPressed = pressed
            return pressed ? .buttonDown : .buttonUp
        }

        if message.function == 1, let xy = ReprogControls.rawXY(from: message.params) {
            return .rawXY(dx: xy.dx, dy: xy.dy)
        }

        return nil
    }

    private func findFeature(deviceIndex: UInt8) -> UInt8? {
        let featureID = ReprogControls.featureID
        let response = transport.request(
            deviceIndex: deviceIndex,
            featureIndex: ReprogControls.rootFeatureIndex,
            function: 0,
            params: [UInt8(featureID >> 8), UInt8(featureID & 0xFF), 0]
        )
        guard let index = response?.params.first, index != 0 else { return nil }
        return index
    }

    private func readControls(deviceIndex: UInt8, featureIndex: UInt8) -> [ReprogControl] {
        guard
            let count = transport.request(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                function: 0,
                params: []
            )?.params.first
        else { return [] }

        return (0..<count).compactMap { controlIndex in
            guard
                let params = transport.request(
                    deviceIndex: deviceIndex,
                    featureIndex: featureIndex,
                    function: 1,
                    params: [controlIndex]
                )?.params,
                let control = ReprogControls.control(from: params)
            else { return nil }
            return control
        }
    }

    private func configureReporting(
        control: ReprogControl,
        rawXY: Bool,
        deviceIndex: UInt8,
        featureIndex: UInt8
    ) -> ReprogConfiguration? {
        let flags = rawXY ? ReprogControls.rawXYReportingFlags : ReprogControls.divertOnlyReportingFlags
        guard setReporting(
            control.cid,
            flags: flags,
            deviceIndex: deviceIndex,
            featureIndex: featureIndex
        ) else { return nil }

        return ReprogConfiguration(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            control: control,
            rawXYEnabled: rawXY
        )
    }

    private func setReporting(
        _ cid: UInt16,
        flags: UInt8,
        deviceIndex: UInt8,
        featureIndex: UInt8
    ) -> Bool {
        transport.request(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            function: 3,
            params: ReprogControls.reportingParams(cid: cid, flags: flags)
        ) != nil
    }
}
