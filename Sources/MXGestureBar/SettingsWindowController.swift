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
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
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
        window.minSize = NSSize(width: 640, height: 440)
        window.center()

        super.init(window: window)

        Self.applyPreviewAppearance(to: window)

        let host = NSHostingView(rootView: SettingsView(model: model))
        host.sizingOptions = []
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
    @Published var gestureShortcutTexts: [String: [GestureEvent: String]] = [:]
    @Published var clickShortcutTexts: [String: String] = [:]
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

    init(config: AppConfig) {
        self.config = config
        reload(config)
    }

    func reload(_ config: AppConfig) {
        self.config = config
        assignments = config.resolvedAssignments
        clickShortcutTexts = Dictionary(
            uniqueKeysWithValues: GestureButtonCatalog.options.map { option in
                (option.id, config.assignment(forButtonID: option.id).shortcut.displayName)
            }
        )
        gestureShortcutTexts = Dictionary(
            uniqueKeysWithValues: GestureButtonCatalog.options.map { option in
                let assigned = config.assignment(forButtonID: option.id)
                let mappings = assigned.mappings.isEmpty ? AppConfig.defaultMappings : assigned.mappings
                return (
                    option.id,
                    Dictionary(
                        uniqueKeysWithValues: GestureEvent.allCases.map { event in
                            (event, mappings[event.rawValue]?.displayName ?? "")
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

    func clickShortcutBinding(for option: GestureButtonCatalog.Option) -> Binding<String> {
        Binding(
            get: { self.clickShortcutTexts[option.id] ?? "" },
            set: { self.clickShortcutTexts[option.id] = $0 }
        )
    }

    func gestureShortcutBinding(for event: GestureEvent) -> Binding<String> {
        Binding(
            get: { self.gestureShortcutTexts[self.gestureMapButtonID]?[event] ?? "" },
            set: { value in
                var texts = self.gestureShortcutTexts[self.gestureMapButtonID] ?? [:]
                texts[event] = value
                self.gestureShortcutTexts[self.gestureMapButtonID] = texts
            }
        )
    }

    func save() {
        var next = config
        var nextAssignments = assignments

        for option in GestureButtonCatalog.options {
            var assigned = nextAssignments[option.id] ?? ButtonAssignment()
            switch assigned.action {
            case .default:
                break
            case .shortcut:
                let shortcut = Shortcut(text: clickShortcutTexts[option.id] ?? "")
                guard shortcut.isValid else {
                    statusIsError = true
                    status = "Invalid shortcut for \(option.title)"
                    return
                }
                assigned.shortcut = shortcut
            case .gesture:
                var mappings: [String: Shortcut] = [:]
                for event in GestureEvent.allCases {
                    let shortcut = Shortcut(text: gestureShortcutTexts[option.id]?[event] ?? "")
                    guard shortcut.isValid else {
                        statusIsError = true
                        status = "Invalid \(event.rawValue) shortcut for \(option.title)"
                        return
                    }
                    mappings[event.rawValue] = shortcut
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
        if gestureShortcutTexts[buttonID] == nil || gestureShortcutTexts[buttonID]?.isEmpty == true {
            gestureShortcutTexts[buttonID] = Dictionary(
                uniqueKeysWithValues: GestureEvent.allCases.map { event in
                    (event, AppConfig.defaultMappings[event.rawValue]?.displayName ?? "")
                }
            )
        }
    }
}