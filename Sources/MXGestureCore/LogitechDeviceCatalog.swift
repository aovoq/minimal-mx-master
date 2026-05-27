import Foundation

public enum LogitechDeviceCatalog {
    public static let vendorID = 0x046D
    public static let hidppUsagePage = 0xFF43
    public static let hidppUsage = 0x0202

    public static let knownProducts: [Int: String] = [
        0xB012: "MX Master",
        0xB019: "MX Master 2S",
        0xB023: "MX Master 3",
        0xB028: "MX Master 3",
        0xB034: "MX Master 3S",
        0xB043: "MX Master 3S",
        0xC548: "Logi Bolt Receiver"
    ]

    public static func displayName(productID: Int?, productName: String?) -> String {
        if let productID, let known = knownProducts[productID] {
            return known
        }
        if let productName, !productName.isEmpty {
            return productName
        }
        return "Logitech HID++ device"
    }
}
