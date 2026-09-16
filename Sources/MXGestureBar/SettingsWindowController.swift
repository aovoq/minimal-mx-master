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
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 448),
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
        window.minSize = NSSize(width: 600, height: 400)
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
        case shortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .buttons: return "Buttons"
            case .shortcuts: return "Shortcuts"
            }
        }

        var symbol: String {
            switch self {
            case .buttons: return "computermouse"
            case .shortcuts: return "keyboard"
            }
        }
    }

    @Published var pane: Pane = .buttons
    @Published var shortcutTexts: [GestureEvent: String] = [:]
    @Published var selectedButtonIDs: Set<String> = []
    @Published var status: String = ""
    @Published var statusIsError = false

    var onSave: ((AppConfig) -> Void)?

    private var config: AppConfig

    init(config: AppConfig) {
        self.config = config
        reload(config)
    }

    func reload(_ config: AppConfig) {
        self.config = config
        shortcutTexts = Dictionary(
            uniqueKeysWithValues: GestureEvent.allCases.map { event in
                (event, config.shortcut(for: event)?.displayName ?? "")
            }
        )
        selectedButtonIDs = Set(
            GestureButtonCatalog.options.compactMap { option in
                GestureButtonCatalog.isSelected(option, cids: config.gestureButtonCIDs) ? option.id : nil
            }
        )
        status = ""
        statusIsError = false
    }

    func shortcutBinding(for event: GestureEvent) -> Binding<String> {
        Binding(
            get: { self.shortcutTexts[event] ?? "" },
            set: { self.shortcutTexts[event] = $0 }
        )
    }

    func buttonBinding(for option: GestureButtonCatalog.Option) -> Binding<Bool> {
        Binding(
            get: { self.selectedButtonIDs.contains(option.id) },
            set: { enabled in
                if enabled {
                    self.selectedButtonIDs.insert(option.id)
                } else {
                    self.selectedButtonIDs.remove(option.id)
                }
            }
        )
    }

    func save() {
        var next = config
        next.gestureButtonCIDs = GestureButtonCatalog.cids(fromSelectedIDs: selectedButtonIDs)

        for event in GestureEvent.allCases {
            let shortcut = Shortcut(text: shortcutTexts[event] ?? "")
            guard shortcut.isValid else {
                statusIsError = true
                status = "Invalid shortcut for \(event.rawValue)"
                return
            }
            next.setShortcut(shortcut, for: event)
        }

        next.save()
        config = next
        reload(next)
        statusIsError = false
        status = "Saved"
        onSave?(next)
    }
}
