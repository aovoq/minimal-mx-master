import Foundation
import IOKit.hid

extension HIDDeviceManager {
    static func key(for device: IOHIDDevice) -> Int {
        Int(bitPattern: Unmanaged.passUnretained(device).toOpaque())
    }

    static func matchedDescriptors(manager: IOHIDManager) -> [HIDDeviceDescriptor] {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return devices
            .map(HIDDeviceDescriptor.init)
            .sorted { $0.summary < $1.summary }
    }

    static func returnName(_ result: IOReturn) -> String {
        switch result {
        case kIOReturnExclusiveAccess:
            return "kIOReturnExclusiveAccess"
        case kIOReturnNotPermitted:
            return "kIOReturnNotPermitted"
        case kIOReturnNotPrivileged:
            return "kIOReturnNotPrivileged"
        case kIOReturnBusy:
            return "kIOReturnBusy"
        default:
            return "\(result)"
        }
    }

    static let deviceMatched: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else { return }
        Unmanaged<HIDDeviceManager>
            .fromOpaque(context)
            .takeUnretainedValue()
            .matched(device: device)
    }

    static let deviceRemoved: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else { return }
        Unmanaged<HIDDeviceManager>
            .fromOpaque(context)
            .takeUnretainedValue()
            .removed(device: device)
    }

    static let inputReport: IOHIDReportCallback = {
        context, _, sender, _, reportID, report, reportLength in
        guard let context, let sender else { return }
        let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
        Unmanaged<HIDDeviceManager>
            .fromOpaque(context)
            .takeUnretainedValue()
            .report(device: unsafeBitCast(sender, to: IOHIDDevice.self), reportID: UInt8(reportID), bytes: bytes)
    }
}
