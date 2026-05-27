import Foundation
import IOKit.hid

struct HIDDeviceDescriptor: Equatable {
    var name: String
    var vendorID: Int?
    var productID: Int?
    var transport: String?
    var requiresTCC: Bool

    init(device: IOHIDDevice) {
        vendorID = Self.intProperty(device, kIOHIDVendorIDKey)
        productID = Self.intProperty(device, kIOHIDProductIDKey)
        transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String
        requiresTCC = Self.boolProperty(device, "RequiresTCCAuthorization")
        name = LogitechDeviceCatalog.displayName(
            productID: productID,
            productName: IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
        )
    }

    var summary: String {
        let product = productID.map { String(format: "0x%04X", $0) } ?? "unknown"
        let suffix = requiresTCC ? " requires input monitoring" : ""
        return "\(name) pid=\(product) \(transport ?? "unknown")\(suffix)"
    }

    private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
        IOHIDDeviceGetProperty(device, key as CFString) as? Int
    }

    private static func boolProperty(_ device: IOHIDDevice, _ key: String) -> Bool {
        (IOHIDDeviceGetProperty(device, key as CFString) as? Bool) ?? false
    }
}
