import OSLog

public enum AppLog {
    public static let app = Logger(subsystem: "dev.aovoq.MXGestureBar", category: "App")
    public static let hid = Logger(subsystem: "dev.aovoq.MXGestureBar", category: "HID")
    public static let gesture = Logger(subsystem: "dev.aovoq.MXGestureBar", category: "Gesture")
}
