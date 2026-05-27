import Foundation
import IOKit.hid

public final class HIDDeviceManager {
    public var onStatusChanged: ((HIDDeviceStatus) -> Void)?
    public var onGestureSignal: ((HIDGestureSignal) -> Void)?

    private final class Session {
        let device: IOHIDDevice
        let buffer: UnsafeMutablePointer<UInt8>
        let client: HIDPPClient
        let name: String

        init(device: IOHIDDevice, name: String) {
            self.device = device
            self.name = name
            self.buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
            self.buffer.initialize(repeating: 0, count: 64)
            self.client = HIDPPClient(device: device)
        }

        deinit {
            buffer.deinitialize(count: 64)
            buffer.deallocate()
        }
    }

    private let lock = NSLock()
    private var manager: IOHIDManager?
    private var sessions: [Int: Session] = [:]
    private var activeKey: Int?

    public init() {}

    public var rawXYEnabled: Bool {
        guard
            let activeKey,
            let session = lock.withLock({ sessions[activeKey] })
        else { return false }
        return session.client.rawXYEnabled
    }

    public func start() {
        guard manager == nil else { return }

        let newManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(newManager, [
            kIOHIDVendorIDKey: LogitechDeviceCatalog.vendorID,
            kIOHIDDeviceUsagePageKey: LogitechDeviceCatalog.hidppUsagePage,
            kIOHIDDeviceUsageKey: LogitechDeviceCatalog.hidppUsage
        ] as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(newManager, Self.deviceMatched, context)
        IOHIDManagerRegisterDeviceRemovalCallback(newManager, Self.deviceRemoved, context)

        let openResult = IOHIDManagerOpen(newManager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            AppLog.hid.error("HID manager open failed: \(openResult)")
            IOHIDManagerClose(newManager, IOOptionBits(kIOHIDOptionsTypeNone))
            publishStatus(HIDDeviceStatus(
                connected: false,
                name: "HID manager open failed \(openResult)",
                rawXYEnabled: false
            ))
            return
        }

        manager = newManager
        IOHIDManagerScheduleWithRunLoop(newManager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    }

    public func restart() {
        stop()
        start()
    }

    public func stop() {
        let existing = lock.withLock {
            let values = Array(sessions.values)
            sessions.removeAll()
            activeKey = nil
            return values
        }
        existing.forEach {
            $0.client.restoreDefaultReporting()
        }
        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        onStatusChanged?(HIDDeviceStatus(connected: false, name: "Not connected", rawXYEnabled: false))
    }

    private func matched(device: IOHIDDevice) {
        let descriptor = HIDDeviceDescriptor(device: device)
        AppLog.hid.info("Matched HID device: \(descriptor.summary, privacy: .public)")

        let key = Self.key(for: device)
        let session = Session(device: device, name: descriptor.name)
        session.client.onGestureSignal = { [weak self] signal in
            self?.onGestureSignal?(signal)
        }

        lock.withLock { sessions[key] = session }
        IOHIDDeviceRegisterInputReportCallback(
            device,
            session.buffer,
            64,
            Self.inputReport,
            Unmanaged.passUnretained(self).toOpaque()
        )

        DispatchQueue.global(qos: .utility).async { [weak self, weak session] in
            guard let self, let session else { return }
            guard let configuration = session.client.configureGesture() else {
                guard self.containsSession(session, key: key) else { return }
                self.publishStatus(HIDDeviceStatus(
                    connected: true,
                    name: "\(session.name) (no gesture CID)",
                    rawXYEnabled: false
                ))
                return
            }

            guard self.containsSession(session, key: key) else { return }
            self.lock.withLock { self.activeKey = key }
            self.publishStatus(HIDDeviceStatus(
                connected: true,
                name: "\(session.name) CID 0x\(String(configuration.control.cid, radix: 16))",
                rawXYEnabled: configuration.rawXYEnabled,
                gestureConfigured: true
            ))
        }
    }

    private func removed(device: IOHIDDevice) {
        let key = Self.key(for: device)
        lock.withLock {
            if activeKey == key { activeKey = nil }
            sessions.removeValue(forKey: key)
        }
        publishStatus(HIDDeviceStatus(connected: false, name: "Not connected", rawXYEnabled: false))
    }

    private func report(device: IOHIDDevice, reportID: UInt8, bytes: [UInt8]) {
        let key = Self.key(for: device)
        let session = lock.withLock { sessions[key] }
        session?.client.receive(reportID: reportID, bytes: bytes)
    }

    private func containsSession(_ session: Session, key: Int) -> Bool {
        lock.withLock { sessions[key] === session }
    }

    private func publishStatus(_ status: HIDDeviceStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChanged?(status)
        }
    }

    private static func key(for device: IOHIDDevice) -> Int {
        Int(bitPattern: Unmanaged.passUnretained(device).toOpaque())
    }

    private static let deviceMatched: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else { return }
        Unmanaged<HIDDeviceManager>
            .fromOpaque(context)
            .takeUnretainedValue()
            .matched(device: device)
    }

    private static let deviceRemoved: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else { return }
        Unmanaged<HIDDeviceManager>
            .fromOpaque(context)
            .takeUnretainedValue()
            .removed(device: device)
    }

    private static let inputReport: IOHIDReportCallback = {
        context, _, sender, _, reportID, report, reportLength in
        guard let context, let sender else { return }
        let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
        Unmanaged<HIDDeviceManager>
            .fromOpaque(context)
            .takeUnretainedValue()
            .report(device: unsafeBitCast(sender, to: IOHIDDevice.self), reportID: UInt8(reportID), bytes: bytes)
    }
}
