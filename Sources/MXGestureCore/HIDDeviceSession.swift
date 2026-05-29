import Foundation
import IOKit.hid

final class HIDDeviceSession {
    static let reportBufferSize = 64

    let device: IOHIDDevice
    let buffer: UnsafeMutablePointer<UInt8>
    let client: HIDPPClient
    let name: String

    init(device: IOHIDDevice, name: String) {
        self.device = device
        self.name = name
        self.buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.reportBufferSize)
        self.buffer.initialize(repeating: 0, count: Self.reportBufferSize)
        self.client = HIDPPClient(device: device)
    }

    deinit {
        buffer.deinitialize(count: Self.reportBufferSize)
        buffer.deallocate()
    }
}
