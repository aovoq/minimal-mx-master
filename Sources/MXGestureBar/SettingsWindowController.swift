import AppKit
import SwiftUI
import MXGestureCore

final class SettingsWindowController: NSWindowController {
    var onSave: ((AppConfig) -> Void)? {
        didSet { model.onSave = onSave }
    }

    private let model: SettingsModel

    init(config: AppConfig) {
        let model = SettingsModel(config: config)
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 640, height: 500)
        window.center()

        super.init(window: window)

        Self.applyPreviewAppearance(to: window)

        let host = NSHostingView(rootView: SettingsView(model: model))
        host.sizingOptions = []
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = host
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(config: AppConfig) {
        model.reload(config)
    }

    static func applyPreviewAppearance(to window: NSWindow) {
        guard let name = previewAppearanceName() else { return }
        window.appearance = NSAppearance(named: name)
    }

    private static func previewAppearanceName() -> NSAppearance.Name? {
        let env = ProcessInfo.processInfo.environment["MXGESTUREBAR_APPEARANCE"]?.lowercased()
        if env == "dark" { return .darkAqua }
        if env == "light" { return .aqua }

        if CommandLine.arguments.contains("--appearance=dark") { return .darkAqua }
        if CommandLine.arguments.contains("--appearance=light") { return .aqua }

        if let index = CommandLine.arguments.firstIndex(of: "--appearance"),
           CommandLine.arguments.indices.contains(index + 1) {
            switch CommandLine.arguments[index + 1].lowercased() {
            case "dark": return .darkAqua
            case "light": return .aqua
            default: break
            }
        }
        return nil
    }
}

final class SettingsModel: ObservableObject {
    enum Pane: String, CaseIterable, Identifiable {
        case buttons
        case gestures
        case wheels

        var id: String { rawValue }

        var title: String {
            switch self {
            case .buttons: return "Buttons"
            case .gestures: return "Gestures"
            case .wheels: return "Wheels"
            }
        }

        var symbol: String {
            switch self {
            case .buttons: return "computermouse"
            case .gestures: return "hand.draw"
            case .wheels: return "arrow.up.arrow.down"
            }
        }
    }

    @Published var pane: Pane = .buttons
    @Published var assignments: [String: ButtonAssignment] = [:]
    @Published var gestureMapButtonID: String = "gesture"
    @Published var gestureShortcuts: [String: [GestureEvent: Shortcut]] = [:]
    @Published var clickShortcuts: [String: Shortcut] = [:]
    @Published var invertMainWheel = false
    @Published var invertThumbWheel = false
    @Published var status: String = ""
    @Published var statusIsError = false

    var onSave: ((AppConfig) -> Void)?

    private var config: AppConfig

    var gestureMapButtonIDs: [String] {
        GestureButtonCatalog.options
            .filter { assignments[$0.id]?.action == .gesture }
            .map(\.id)
    }

    var canSave: Bool {
        activeShortcutSlots.allSatisfy { slot, shortcut in
            ShortcutFieldIssue.evaluate(shortcut, others: others(excluding: slot)) == nil
        }
    }

    init(config: AppConfig) {
        self.config = config
        reload(config)
    }

    func reload(_ config: AppConfig) {
        self.config = config
        assignments = config.resolvedAssignments
        clickShortcuts = Dictionary(
            uniqueKeysWithValues: GestureButtonCatalog.options.map { option in
                (option.id, config.assignment(forButtonID: option.id).shortcut)
            }
        )
        gestureShortcuts = Dictionary(
            uniqueKeysWithValues: GestureButtonCatalog.options.map { option in
                let assigned = config.assignment(forButtonID: option.id)
                let mappings = assigned.mappings.isEmpty ? AppConfig.defaultMappings : assigned.mappings
                return (
                    option.id,
                    Dictionary(
                        uniqueKeysWithValues: GestureEvent.allCases.map { event in
                            (event, mappings[event.rawValue] ?? Shortcut(keys: []))
                        }
                    )
                )
            }
        )
        let previousMapButtonID = gestureMapButtonID
        if gestureMapButtonIDs.contains(previousMapButtonID) {
            gestureMapButtonID = previousMapButtonID
        } else if let first = gestureMapButtonIDs.first {
            gestureMapButtonID = first
        }
        invertMainWheel = config.wheels.invertMain
        invertThumbWheel = config.wheels.invertThumb
        status = ""
        statusIsError = false
    }

    func actionBinding(for option: GestureButtonCatalog.Option) -> Binding<ButtonAction> {
        Binding(
            get: { self.assignments[option.id]?.action ?? .default },
            set: { action in
                var assigned = self.assignments[option.id] ?? ButtonAssignment()
                assigned.action = action
                if action == .gesture, assigned.mappings.isEmpty {
                    assigned.mappings = AppConfig.defaultMappings
                    self.ensureGestureShortcutTexts(for: option.id)
                }
                self.assignments[option.id] = assigned
                if action == .gesture, !self.gestureMapButtonIDs.contains(self.gestureMapButtonID) {
                    self.gestureMapButtonID = option.id
                } else if action != .gesture, self.gestureMapButtonID == option.id {
                    self.gestureMapButtonID = self.gestureMapButtonIDs.first ?? "gesture"
                }
            }
        )
    }

    func clickShortcutBinding(for option: GestureButtonCatalog.Option) -> Binding<Shortcut> {
        Binding(
            get: { self.clickShortcuts[option.id] ?? Shortcut(keys: []) },
            set: { self.clickShortcuts[option.id] = $0 }
        )
    }

    func gestureShortcutBinding(for event: GestureEvent) -> Binding<Shortcut> {
        Binding(
            get: { self.gestureShortcuts[self.gestureMapButtonID]?[event] ?? Shortcut(keys: []) },
            set: { value in
                var map = self.gestureShortcuts[self.gestureMapButtonID] ?? [:]
                map[event] = value
                self.gestureShortcuts[self.gestureMapButtonID] = map
            }
        )
    }

    func clickIssue(for option: GestureButtonCatalog.Option) -> ShortcutFieldIssue? {
        guard assignments[option.id]?.action == .shortcut else { return nil }
        let slot = ShortcutSlot.click(option.id)
        return ShortcutFieldIssue.evaluate(
            clickShortcuts[option.id] ?? Shortcut(keys: []),
            others: others(excluding: slot)
        )
    }

    func gestureIssue(for event: GestureEvent) -> ShortcutFieldIssue? {
        let slot = ShortcutSlot.gesture(button: gestureMapButtonID, event: event)
        return ShortcutFieldIssue.evaluate(
            gestureShortcuts[gestureMapButtonID]?[event] ?? Shortcut(keys: []),
            others: others(excluding: slot)
        )
    }

    func save() {
        guard canSave else {
            statusIsError = true
            status = "Fix the highlighted shortcuts"
            return
        }

        var next = config
        var nextAssignments = assignments

        for option in GestureButtonCatalog.options {
            var assigned = nextAssignments[option.id] ?? ButtonAssignment()
            switch assigned.action {
            case .default:
                break
            case .shortcut:
                assigned.shortcut = clickShortcuts[option.id] ?? Shortcut(keys: [])
            case .gesture:
                var mappings: [String: Shortcut] = [:]
                for event in GestureEvent.allCases {
                    mappings[event.rawValue] = gestureShortcuts[option.id]?[event] ?? Shortcut(keys: [])
                }
                assigned.mappings = mappings
            }
            nextAssignments[option.id] = assigned
        }

        next.buttonAssignments = nextAssignments
        next.gestureButtonCIDs = next.gestureCIDs
        next.mappings = nextAssignments[next.primaryGestureButtonID]?.mappings ?? AppConfig.defaultMappings
        next.wheels = WheelSettings(invertMain: invertMainWheel, invertThumb: invertThumbWheel)

        next.save()
        config = next
        reload(next)
        statusIsError = false
        status = "Saved"
        onSave?(next)
    }

    private func ensureGestureShortcutTexts(for buttonID: String) {
        if gestureShortcuts[buttonID] == nil || gestureShortcuts[buttonID]?.isEmpty == true {
            gestureShortcuts[buttonID] = Dictionary(
                uniqueKeysWithValues: GestureEvent.allCases.map { event in
                    (event, AppConfig.defaultMappings[event.rawValue] ?? Shortcut(keys: []))
                }
            )
        }
    }

    private enum ShortcutSlot: Equatable {
        case click(String)
        case gesture(button: String, event: GestureEvent)
    }

    private var activeShortcutSlots: [(ShortcutSlot, Shortcut)] {
        GestureButtonCatalog.options.flatMap { option -> [(ShortcutSlot, Shortcut)] in
            switch assignments[option.id]?.action {
            case .shortcut:
                return [(.click(option.id), clickShortcuts[option.id] ?? Shortcut(keys: []))]
            case .gesture:
                return GestureEvent.allCases.map { event in
                    (.gesture(button: option.id, event: event), gestureShortcuts[option.id]?[event] ?? Shortcut(keys: []))
                }
            default:
                return []
            }
        }
    }

    private func others(excluding slot: ShortcutSlot) -> [Shortcut] {
        activeShortcutSlots.compactMap { $0.0 == slot ? nil : $0.1 }
    }
}