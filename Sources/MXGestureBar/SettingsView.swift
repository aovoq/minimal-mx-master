import AppKit
import SwiftUI
import MXGestureCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 168)
                .frame(maxHeight: .infinity, alignment: .top)
                .background {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                }

            Color(nsColor: .separatorColor)
                .frame(width: 1)
                .ignoresSafeArea()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsModel.Pane.allCases) { pane in
                sidebarItem(pane)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 30)
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    private func sidebarItem(_ pane: SettingsModel.Pane) -> some View {
        let selected = model.pane == pane
        return Button {
            model.pane = pane
        } label: {
            Label(pane.title, systemImage: pane.symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: selected ? .medium : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.primary.opacity(0.08) : Color.clear)
                }
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.primary : Color.secondary)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    switch model.pane {
                    case .buttons:
                        buttonsPane
                    case .shortcuts:
                        shortcutsPane
                    }
                }
                .frame(maxWidth: 540, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }

            footer
        }
    }

    private var buttonsPane: some View {
        paneLayout(
            title: "Gesture buttons",
            subtitle: "Buttons that start a gesture hold. Left and right click stay reserved."
        ) {
            SettingsCard {
                ForEach(Array(GestureButtonCatalog.options.enumerated()), id: \.element.id) { index, option in
                    if index > 0 {
                        SettingsRowDivider()
                    }
                    SettingsRow(title: option.title, symbol: symbol(forButton: option.id)) {
                        Toggle("", isOn: model.buttonBinding(for: option))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .accessibilityLabel(option.title)
                    }
                }
            }
        }
    }

    private var shortcutsPane: some View {
        paneLayout(
            title: "Shortcuts",
            subtitle: "Fired on click and swipe. Use modifier+key, like ctrl+left."
        ) {
            SettingsCard {
                ForEach(Array(GestureEvent.allCases.enumerated()), id: \.element) { index, event in
                    if index > 0 {
                        SettingsRowDivider()
                    }
                    SettingsRow(title: event.rawValue.capitalized, symbol: symbol(forEvent: event)) {
                        ShortcutField(
                            text: model.shortcutBinding(for: event),
                            placeholder: "ctrl+left",
                            accessibilityLabel: event.rawValue
                        )
                        .frame(width: 176, height: 22)
                    }
                }
            }
        }
    }

    private func paneLayout<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.28)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Color(nsColor: .separatorColor)
                .frame(height: 1)

            HStack(spacing: 12) {
                Text(model.status)
                    .font(.system(size: 12))
                    .foregroundStyle(model.statusIsError ? Color.red : Color.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button("Save") {
                    model.save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    private func symbol(forButton id: String) -> String {
        switch id {
        case "gesture": return "hand.draw"
        case "back": return "chevron.left"
        case "forward": return "chevron.right"
        case "middle": return "circle"
        case "smartShift": return "arrow.up.arrow.down"
        default: return "button.horizontal"
        }
    }

    private func symbol(forEvent event: GestureEvent) -> String {
        switch event {
        case .click: return "dot.circle"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

private struct SettingsRow<Trailing: View>: View {
    var title: String
    var symbol: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer(minLength: 12)

            trailing()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
    }
}

private struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 38)
            .opacity(0.65)
    }
}

private struct ShortcutField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var accessibilityLabel: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.bezelStyle = .roundedBezel
        field.controlSize = .small
        field.focusRingType = .default
        field.delegate = context.coordinator
        field.setAccessibilityLabel(accessibilityLabel)
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.sendsActionOnEndEditing = true
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
        field.setAccessibilityLabel(accessibilityLabel)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
