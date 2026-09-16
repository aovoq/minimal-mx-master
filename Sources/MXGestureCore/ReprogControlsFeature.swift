import Foundation

final class ReprogControlsFeature {
    private let transport: HIDPPTransport
    private var configuration: ReprogConfiguration?
    private var previousPressed: Set<UInt16> = []
    private var selectedHoldCID: UInt16?

    init(transport: HIDPPTransport) {
        self.transport = transport
    }

    var rawXYEnabled: Bool {
        configuration?.rawXYEnabled ?? false
    }

    func configureGesture(
        selectedCIDs: [UInt16] = [],
        gestureCIDs: [UInt16]? = nil,
        autoSelectIfEmpty: Bool = true
    ) -> ReprogConfiguration? {
        restoreDefaultReporting()

        for index in ReprogControls.candidateDeviceIndices {
            guard let featureIndex = transport.featureIndex(of: ReprogControls.featureID, deviceIndex: index) else {
                continue
            }
            AppLog.hid.info("Found REPROG_CONTROLS_V4 at index \(featureIndex) deviceIndex \(index)")
            let controls = readControls(deviceIndex: index, featureIndex: featureIndex)
            let selection = ReprogControls.chooseControls(
                from: controls,
                selectedCIDs: selectedCIDs,
                autoSelectIfEmpty: autoSelectIfEmpty
            )
            for skipped in selection.skipped {
                AppLog.hid.error(
                    "Skipping CID 0x\(String(skipped.cid, radix: 16), privacy: .public): \(skipped.reason, privacy: .public)"
                )
            }
            guard !selection.controls.isEmpty else { continue }
            AppLog.hid.info(
                "Selected gesture CIDs \(Self.cidList(selection.controls), privacy: .public)"
            )

            let resolvedGestureCIDs = Set(gestureCIDs ?? selection.controls.map(\.cid))
            let shortcutCIDs = Set(selection.controls.map(\.cid)).subtracting(resolvedGestureCIDs)

            var configuredControls: [ReprogControl] = []
            var rawXYEnabled = false
            for control in selection.controls {
                let asGesture = resolvedGestureCIDs.contains(control.cid)
                if asGesture,
                   shouldTryRawXY(control),
                   let configured = configureReporting(
                    control: control,
                    rawXY: true,
                    deviceIndex: index,
                    featureIndex: featureIndex
                   ) {
                    AppLog.hid.info("Enabled RawXY divert for CID 0x\(String(control.cid, radix: 16), privacy: .public)")
                    configuredControls.append(configured.control)
                    rawXYEnabled = true
                    continue
                }

                if let configured = configureReporting(
                    control: control,
                    rawXY: false,
                    deviceIndex: index,
                    featureIndex: featureIndex
                ) {
                    AppLog.hid.info("Enabled divert without RawXY for CID 0x\(String(control.cid, radix: 16), privacy: .public)")
                    configuredControls.append(configured.control)
                }
            }

            guard !configuredControls.isEmpty else { continue }
            let configuration = ReprogConfiguration(
                deviceIndex: index,
                featureIndex: featureIndex,
                controls: configuredControls,
                rawXYEnabled: rawXYEnabled,
                gestureCIDs: Set(configuredControls.map(\.cid)).intersection(resolvedGestureCIDs),
                shortcutCIDs: shortcutCIDs,
                skipped: selection.skipped
            )
            self.configuration = configuration
            return configuration
        }

        return nil
    }

    func restoreDefaultReporting() {
        guard let configuration else { return }
        for control in configuration.controls {
            _ = transport.send(
                deviceIndex: configuration.deviceIndex,
                featureIndex: configuration.featureIndex,
                function: 3,
                params: ReprogControls.reportingParams(
                    cid: control.cid,
                    flags: ReprogControls.clearReportingFlags
                )
            )
        }
        self.configuration = nil
        previousPressed = []
        selectedHoldCID = nil
    }

    func handleEvent(_ message: HIDPPMessage) -> HIDGestureSignal? {
        guard
            let configuration,
            message.deviceIndex == configuration.deviceIndex,
            message.featureIndex == configuration.featureIndex
        else { return nil }

        if message.function == 0 {
            return handlePressedCIDs(ReprogControls.pressedCIDs(from: message.params), configuration: configuration)
        }

        if message.function == 1, let xy = ReprogControls.rawXY(from: message.params) {
            return .rawXY(dx: xy.dx, dy: xy.dy)
        }

        return nil
    }

    private func handlePressedCIDs(
        _ pressed: Set<UInt16>,
        configuration: ReprogConfiguration
    ) -> HIDGestureSignal? {
        let divertedPressed = pressed.intersection(configuration.selectedCIDs)
        let newlyPressed = divertedPressed.subtracting(previousPressed)
        previousPressed = divertedPressed

        if selectedHoldCID == nil, let cid = newlyPressed.first(where: { configuration.shortcutCIDs.contains($0) }) {
            return .buttonDown(cid: cid)
        }

        let gesturePressed = divertedPressed.intersection(configuration.gestureCIDs)
        if selectedHoldCID == nil, let cid = newlyPressed.first(where: { configuration.gestureCIDs.contains($0) }) {
            selectedHoldCID = cid
            return .buttonDown(cid: cid)
        }

        if let hold = selectedHoldCID, gesturePressed.isEmpty {
            selectedHoldCID = nil
            return .buttonUp(cid: hold)
        }

        return nil
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

    private func shouldTryRawXY(_ control: ReprogControl) -> Bool {
        control.hasRawXY || ReprogControls.preferredGestureCIDs.contains(control.cid)
    }

    private static func cidList(_ controls: [ReprogControl]) -> String {
        controls.map { "0x\(String($0.cid, radix: 16))" }.joined(separator: ", ")
    }
}