import Foundation
import IOKit.hid

public final class HIDDeviceManager {
    public var onStatusChanged: ((HIDDeviceStatus) -> Void)?
    public var onGestureSignal: ((HIDGestureSignal) -> Void)?

    private let lock = NSLock()
    private var manager: IOHIDManager?
    private var sessions: [Int: HIDDeviceSession] = [:]
    private var activeKey: Int?
    private var nextOpenAttemptAt = Date.distantPast

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
        guard Date() >= nextOpenAttemptAt else { return }

        let newManager = makeManager()
        let matchedDescriptors = Self.matchedDescriptors(manager: newManager)
        let openResult = IOHIDManagerOpen(newManager, IOOptionBits(kIOHIDOptionsTypeNone))

        guard openResult == kIOReturnSuccess else {
            handleOpenFailure(openResult, manager: newManager, descriptors: matchedDescriptors)
            return
        }

        nextOpenAttemptAt = .distantPast
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
        nextOpenAttemptAt = .distantPast
        onStatusChanged?(.notConnected)
    }

    private func makeManager() -> IOHIDManager {
        let newManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(newManager, [
            kIOHIDVendorIDKey: LogitechDeviceCatalog.vendorID,
            kIOHIDDeviceUsagePageKey: LogitechDeviceCatalog.hidppUsagePage,
            kIOHIDDeviceUsageKey: LogitechDeviceCatalog.hidppUsage
        ] as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(newManager, Self.deviceMatched, context)
        IOHIDManagerRegisterDeviceRemovalCallback(newManager, Self.deviceRemoved, context)
        return newManager
    }

    private func handleOpenFailure(
        _ result: IOReturn,
        manager newManager: IOHIDManager,
        descriptors: [HIDDeviceDescriptor]
    ) {
        nextOpenAttemptAt = Date().addingTimeInterval(5)
        AppLog.hid.error("HID manager open failed: \(result) \(Self.returnName(result), privacy: .public)")
        IOHIDManagerClose(newManager, IOOptionBits(kIOHIDOptionsTypeNone))

        if result == kIOReturnExclusiveAccess, let descriptor = descriptors.first {
            publishStatus(.hidBusyFallback(deviceName: descriptor.name))
            return
        }

        publishStatus(.openFailed(returnName: Self.returnName(result)))
    }

    func matched(device: IOHIDDevice) {
        let descriptor = HIDDeviceDescriptor(device: device)
        AppLog.hid.info("Matched HID device: \(descriptor.summary, privacy: .public)")

        let key = Self.key(for: device)
        let session = HIDDeviceSession(device: device, name: descriptor.name)
        session.client.onGestureSignal = { [weak self] signal in
            self?.onGestureSignal?(signal)
        }

        lock.withLock { sessions[key] = session }
        IOHIDDeviceRegisterInputReportCallback(
            device,
            session.buffer,
            HIDDeviceSession.reportBufferSize,
            Self.inputReport,
            Unmanaged.passUnretained(self).toOpaque()
        )

        configureGesture(for: session, key: key)
    }

    func removed(device: IOHIDDevice) {
        let key = Self.key(for: device)
        lock.withLock {
            if activeKey == key { activeKey = nil }
            sessions.removeValue(forKey: key)
        }
        publishStatus(.notConnected)
    }

    func report(device: IOHIDDevice, reportID: UInt8, bytes: [UInt8]) {
        let key = Self.key(for: device)
        let session = lock.withLock { sessions[key] }
        session?.client.receive(reportID: reportID, bytes: bytes)
    }

    private func configureGesture(for session: HIDDeviceSession, key: Int) {
        DispatchQueue.global(qos: .utility).async { [weak self, weak session] in
            guard let self, let session else { return }
            guard let configuration = session.client.configureGesture() else {
                guard self.containsSession(session, key: key) else { return }
                self.publishStatus(.noGestureCID(deviceName: session.name))
                return
            }

            guard self.containsSession(session, key: key) else { return }
            self.lock.withLock { self.activeKey = key }
            self.publishStatus(.configured(deviceName: session.name, configuration: configuration))
        }
    }

    private func containsSession(_ session: HIDDeviceSession, key: Int) -> Bool {
        lock.withLock { sessions[key] === session }
    }

    private func publishStatus(_ status: HIDDeviceStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChanged?(status)
        }
    }
}
