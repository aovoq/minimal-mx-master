import AppKit
import MXGestureCore

final class SettingsWindowController: NSWindowController {
    var onSave: ((AppConfig) -> Void)?

    private var config: AppConfig
    private var fields: [GestureEvent: NSTextField] = [:]
    private var buttonChecks: [String: NSButton] = [:]
    private let statusLabel = NSTextField(labelWithString: "")

    init(config: AppConfig) {
        self.config = config
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "MXGestureBar Settings"
        window.center()
        buildContent(in: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(config: AppConfig) {
        self.config = config
        for event in GestureEvent.allCases {
            fields[event]?.stringValue = config.shortcut(for: event)?.displayName ?? ""
        }
        refreshButtonChecks()
        statusLabel.stringValue = ""
    }

    private func buildContent(in window: NSWindow) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])

        stack.addArrangedSubview(sectionLabel("Gesture buttons"))
        stack.addArrangedSubview(buttonCheckRows())

        for event in GestureEvent.allCases {
            stack.addArrangedSubview(row(for: event))
        }

        statusLabel.textColor = .systemRed
        stack.addArrangedSubview(statusLabel)

        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        stack.addArrangedSubview(save)
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    private func buttonCheckRows() -> NSView {
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.spacing = 6
        rows.alignment = .leading

        let options = GestureButtonCatalog.options
        let chunks = stride(from: 0, to: options.count, by: 3).map {
            Array(options[$0..<min($0 + 3, options.count)])
        }
        for chunk in chunks {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 16
            row.alignment = .centerY
            for option in chunk {
                let checkbox = NSButton(checkboxWithTitle: option.title, target: nil, action: nil)
                checkbox.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                buttonChecks[option.id] = checkbox
                row.addArrangedSubview(checkbox)
            }
            rows.addArrangedSubview(row)
        }
        refreshButtonChecks()
        return rows
    }

    private func refreshButtonChecks() {
        for option in GestureButtonCatalog.options {
            buttonChecks[option.id]?.state = GestureButtonCatalog.isSelected(
                option,
                cids: config.gestureButtonCIDs
            ) ? .on : .off
        }
    }

    private func row(for event: GestureEvent) -> NSView {
        let label = NSTextField(labelWithString: event.rawValue)
        label.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let field = NSTextField(string: config.shortcut(for: event)?.displayName ?? "")
        field.placeholderString = "ctrl+left"
        fields[event] = field

        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.spacing = 10
        return row
    }

    @objc private func save() {
        statusLabel.textColor = .systemRed
        var next = config
        let selectedIDs = Set(
            buttonChecks.compactMap { id, button in
                button.state == .on ? id : nil
            }
        )
        next.gestureButtonCIDs = GestureButtonCatalog.cids(fromSelectedIDs: selectedIDs)

        for event in GestureEvent.allCases {
            let shortcut = Shortcut(text: fields[event]?.stringValue ?? "")
            guard shortcut.isValid else {
                statusLabel.stringValue = "Invalid shortcut for \(event.rawValue)"
                return
            }
            next.setShortcut(shortcut, for: event)
        }
        next.save()
        config = next
        refreshButtonChecks()
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Saved"
        onSave?(next)
    }
}
