import AppKit
import SwiftUI
import MXGestureCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 168)
                .frame(maxHeight: .infinity, alignment: .top)
                .background {
                    (colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.028))
                        .ignoresSafeArea()
                }

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
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
                .labelStyle(SidebarLabelStyle())
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
                    case .gestures:
                        gesturesPane
                    case .wheels:
                        wheelsPane
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
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
            title: "Buttons",
            subtitle: "What each button does. Gesture starts a hold with that button’s own swipe map. Diverting replaces the native click; left and right stay native unless the mouse can divert them."
        ) {
            SettingsCard {
                ForEach(Array(GestureButtonCatalog.options.enumerated()), id: \.element.id) { index, option in
                    if index > 0 {
                        SettingsRowDivider()
                    }
                    SettingsRow(title: option.title, symbol: symbol(forButton: option.id)) {
                        HStack(alignment: .center, spacing: 8) {
                            if model.assignments[option.id]?.action == .shortcut {
                                VStack(alignment: .trailing, spacing: 2) {
                                    ShortcutRecorder(
                                        shortcut: model.clickShortcutBinding(for: option),
                                        accessibilityLabel: "\(option.title) shortcut"
                                    )
                                    .frame(width: 108, height: 22)
                                    IssueCaption(issue: model.clickIssue(for: option))
                                }
                            }
                            Picker("", selection: model.actionBinding(for: option)) {
                                ForEach(ButtonAction.allCases, id: \.self) { action in
                                    Text(action.title).tag(action)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 112)
                            .accessibilityLabel(option.title)
                        }
                    }
                }
            }
        }
    }

    private var gesturesPane: some View {
        paneLayout(
            title: "Gestures",
            subtitle: "Record a shortcut for click and each swipe. Back, Gesture, and Smart Shift can each have a different map."
        ) {
            if model.gestureMapButtonIDs.isEmpty {
                SettingsCard {
                    SettingsRow(title: "No gesture buttons", symbol: "hand.draw") {
                        Text("Set a button to Gesture")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                SettingsCard {
                    SettingsRow(title: "Button", symbol: "computermouse") {
                        Picker("", selection: $model.gestureMapButtonID) {
                            ForEach(model.gestureMapButtonIDs, id: \.self) { id in
                                Text(GestureButtonCatalog.option(id: id)?.title ?? id).tag(id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 140)
                        .accessibilityLabel("Gesture button")
                    }
                }

                SettingsCard {
                    GesturePadView(model: model)
                }
            }
        }
    }

    private var wheelsPane: some View {
        paneLayout(
            title: "Wheels",
            subtitle: "Rotation direction for the main scroll wheel and the thumb wheel. Inverted uses the mouse HID++ invert flag when the device exposes it."
        ) {
            SettingsCard {
                SettingsRow(title: "Main wheel", symbol: "arrow.up.arrow.down") {
                    Picker("", selection: $model.invertMainWheel) {
                        Text("Default").tag(false)
                        Text("Inverted").tag(true)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 112)
                    .accessibilityLabel("Main wheel direction")
                }
                SettingsRowDivider()
                SettingsRow(title: "Thumb wheel", symbol: "arrow.left.arrow.right") {
                    Picker("", selection: $model.invertThumbWheel) {
                        Text("Default").tag(false)
                        Text("Inverted").tag(true)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 112)
                    .accessibilityLabel("Thumb wheel direction")
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
            Color.primary.opacity(0.06)
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
                .disabled(!model.canSave)
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
        case "left": return "computermouse"
        case "middle": return "circle"
        case "right": return "computermouse.fill"
        case "smartShift": return "arrow.up.arrow.down"
        default: return "button.horizontal"
        }
    }
}

private struct SidebarLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 13))
                .symbolRenderingMode(.monochrome)
                .frame(width: 18, height: 16, alignment: .center)
            configuration.title
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(.vertical, 6)
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

private struct IssueCaption: View {
    var issue: ShortcutFieldIssue?

    var body: some View {
        Text(issue?.message ?? " ")
            .font(.system(size: 11))
            .foregroundStyle(issue == nil ? Color.clear : Color.red)
            .frame(minHeight: 14)
            .accessibilityHidden(issue == nil)
    }
}

private struct GesturePadView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .frame(width: 92, height: 268)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .frame(width: 320, height: 92)

            VStack(spacing: 14) {
                padSlot(.up)
                HStack(spacing: 18) {
                    padSlot(.left)
                    padSlot(.click)
                    padSlot(.right)
                }
                padSlot(.down)
            }
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func padSlot(_ event: GestureEvent) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if event == .click {
                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                        .frame(width: 36, height: 36)
                }
                Image(systemName: symbol(for: event))
                    .font(.system(size: event == .click ? 13 : 15, weight: .semibold))
                    .foregroundStyle(event == .click ? Color.primary : Color.secondary)
            }
            .frame(height: 36)

            ShortcutRecorder(
                shortcut: model.gestureShortcutBinding(for: event),
                accessibilityLabel: "\(model.gestureMapButtonID) \(event.rawValue)"
            )
            .frame(width: 108, height: 22)

            IssueCaption(issue: model.gestureIssue(for: event))
        }
        .frame(width: 116)
    }

    private func symbol(for event: GestureEvent) -> String {
        switch event {
        case .click: return "dot.circle"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
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