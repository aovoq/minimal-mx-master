import AppKit
import SwiftUI
import MXGestureCore

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut
    var accessibilityLabel: String

    func makeCoordinator() -> Coordinator {
        Coordinator(shortcut: $shortcut)
    }

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.coordinator = context.coordinator
        view.representedShortcut = shortcut
        view.setAccessibilityLabel(accessibilityLabel)
        view.setAccessibilityIdentifier(accessibilityLabel)
        return view
    }

    func updateNSView(_ view: ShortcutRecorderNSView, context: Context) {
        context.coordinator.shortcut = $shortcut
        if !view.isRecording, view.representedShortcut != shortcut {
            view.representedShortcut = shortcut
        }
        view.setAccessibilityLabel(accessibilityLabel)
        view.setAccessibilityIdentifier(accessibilityLabel)
        view.needsDisplay = true
    }

    final class Coordinator {
        var shortcut: Binding<Shortcut>

        init(shortcut: Binding<Shortcut>) {
            self.shortcut = shortcut
        }
    }
}

final class ShortcutRecorderNSView: NSView {
    var coordinator: ShortcutRecorder.Coordinator?
    var representedShortcut = Shortcut(keys: []) {
        didSet { needsDisplay = true }
    }

    private(set) var isRecording = false {
        didSet { needsDisplay = true }
    }

    private var snapshotBeforeRecord: Shortcut?
    private var liveFlags: CGEventFlags = []
    private var monitor: Any?

    override var intrinsicContentSize: NSSize {
        NSSize(width: 108, height: 22)
    }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        focusRingType = .none
        setAccessibilityRole(.button)
        setAccessibilityIdentifier("shortcut-recorder")
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        removeMonitor()
    }

    override func accessibilityValue() -> Any? {
        if isRecording { return liveLabel }
        return representedShortcut.keys.isEmpty ? nil : representedShortcut.glyphDisplay
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        snapshotBeforeRecord = representedShortcut
        isRecording = true
        liveFlags = []
        installMonitor()
        setAccessibilityValue("Recording")
        return true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            cancelRecording()
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        apply(recordResult(from: event))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        apply(recordResult(from: event))
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        liveFlags = cgFlags(from: event)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        if isRecording {
            NSColor.controlAccentColor.setStroke()
        } else {
            NSColor.separatorColor.withAlphaComponent(0.7).setStroke()
        }
        path.lineWidth = 1
        path.stroke()

        let text = displayText as NSString
        let color: NSColor = {
            if isRecording { return .controlAccentColor }
            if representedShortcut.keys.isEmpty { return .placeholderTextColor }
            return .labelColor
        }()
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = text.size(withAttributes: attributes)
        let origin = NSPoint(
            x: ((self.bounds.width - size.width) / 2).rounded(.down),
            y: ((self.bounds.height - size.height) / 2).rounded(.down)
        )
        text.draw(at: origin, withAttributes: attributes)
    }

    private var displayText: String {
        if isRecording { return liveLabel }
        if representedShortcut.keys.isEmpty { return "Record" }
        return representedShortcut.glyphDisplay
    }

    private var liveLabel: String {
        let glyphs = Shortcut.modifierGlyphs(from: liveFlags)
        return glyphs.isEmpty ? "Recording" : glyphs
    }

    private func recordResult(from event: NSEvent) -> ShortcutRecordResult {
        Shortcut.record(
            keyCode: CGKeyCode(event.keyCode),
            flags: cgFlags(from: event),
            isRepeat: event.isARepeat
        )
    }

    private func apply(_ result: ShortcutRecordResult) {
        switch result {
        case let .captured(shortcut):
            representedShortcut = shortcut
            coordinator?.shortcut.wrappedValue = shortcut
            stopRecording()
            window?.makeFirstResponder(nil)
        case .clear:
            representedShortcut = Shortcut(keys: [])
            coordinator?.shortcut.wrappedValue = Shortcut(keys: [])
            stopRecording()
            window?.makeFirstResponder(nil)
        case .cancel:
            cancelRecording()
            window?.makeFirstResponder(nil)
        case .ignore:
            break
        }
    }

    private func cancelRecording() {
        if let snapshotBeforeRecord {
            representedShortcut = snapshotBeforeRecord
        }
        stopRecording()
    }

    private func stopRecording() {
        isRecording = false
        liveFlags = []
        snapshotBeforeRecord = nil
        removeMonitor()
        needsDisplay = true
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.window?.firstResponder === self else { return event }
            if event.type == .flagsChanged {
                self.flagsChanged(with: event)
                return nil
            }
            self.apply(self.recordResult(from: event))
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func cgFlags(from event: NSEvent) -> CGEventFlags {
        var flags: CGEventFlags = []
        if event.modifierFlags.contains(.control) { flags.insert(.maskControl) }
        if event.modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
        if event.modifierFlags.contains(.shift) { flags.insert(.maskShift) }
        if event.modifierFlags.contains(.command) { flags.insert(.maskCommand) }
        if event.modifierFlags.contains(.function) { flags.insert(.maskSecondaryFn) }
        if event.modifierFlags.contains(.numericPad) { flags.insert(.maskNumericPad) }
        return flags
    }
}
