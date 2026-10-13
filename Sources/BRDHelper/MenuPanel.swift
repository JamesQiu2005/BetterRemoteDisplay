import BRDShared
import SwiftUI

/// The menu bar panel, laid out like the system's own menu bar extras (Wi-Fi, Display):
/// a title with a switch, then a list whose rows carry a round icon that fills with the
/// accent colour when active. Glass (macOS 26 and later) is kept to the controls; the list
/// itself is plain content.
struct MenuPanel: View {
    @Environment(HelperModel.self) private var model
    @State private var category: DeviceCategory = .mac

    private var config: Config { model.config }

    var body: some View {
        VStack(spacing: 12) {
            header
            CategoryPicker(selection: $category)
            presetList
            Divider()
                .padding(.horizontal, 6)
            footer
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { category = config.currentPreset?.category ?? category }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remote Display")
                    .font(.headline)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Toggle("Virtual Display", isOn: Binding(
                get: { config.enabled },
                set: { on in model.store.update { $0.enabled = on } }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.horizontal, 6)
    }

    private var status: String {
        guard config.enabled else { return "Off" }
        guard model.isHealthy else { return "Couldn’t create display" }
        if let fallback = model.fallbackSize { return "Too small for macOS · using \(fallback.label)" }
        return config.size.label
    }

    private var presetList: some View {
        let presets = config.menuPresets(in: category)
        return Group {
            if presets.isEmpty {
                Text(category == .custom ? "Add custom resolutions in Settings." : "No presets shown. Choose some in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: PresetRow.height * 2)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(presets) { preset in
                            PresetRow(preset: preset,
                                      isSelected: config.enabled && preset.size.matches(config.size)) {
                                model.select(preset)
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
                .softScrollEdges()
                // Half a row peeks out when the list is longer, so it reads as scrollable.
                .frame(height: min(CGFloat(presets.count), 6.5) * PresetRow.height)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                model.rotate()
            } label: {
                Label("Rotate", systemImage: "rotate.right")
            }
            .help(config.size.isPortrait ? "Switch to landscape" : "Switch to portrait")
            .disabled(!config.enabled)
            Spacer()
            Button("Settings…") { model.openSettings() }
        }
        .glassButtons()
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}

// Liquid Glass arrived in macOS 26. Earlier systems get the closest standard look.
private extension View {
    @ViewBuilder
    func glassButtons() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func softScrollEdges() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .vertical)
        } else {
            self
        }
    }

    @ViewBuilder
    func segmentThumb(isSelected: Bool) -> some View {
        if #available(macOS 26, *) {
            glassEffect(isSelected ? .regular.interactive() : .identity, in: .capsule)
        } else {
            background(.primary.opacity(isSelected ? 0.14 : 0), in: .capsule)
        }
    }
}

/// Capsule segmented control with a glass thumb.
private struct CategoryPicker: View {
    @Binding var selection: DeviceCategory

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DeviceCategory.allCases) { category in
                let isSelected = category == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = category }
                } label: {
                    Text(category.title)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(.capsule)
                        .segmentThumb(isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.primary.opacity(0.08), in: .capsule)
    }
}

private struct PresetRow: View {
    static let height: CGFloat = 46

    let preset: DisplayPreset
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .frame(width: 30, height: 30)
                    .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary.opacity(0.1)),
                                in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .lineLimit(1)
                    if let variant = preset.variant {
                        Text(variant)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(preset.size.label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .layoutPriority(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: Self.height - 4)
            .background(.primary.opacity(isHovered ? 0.08 : 0), in: .rect(cornerRadius: 14, style: .continuous))
            .padding(.vertical, 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var symbol: String {
        switch preset.category {
        case .ipad: "ipad.landscape"
        case .iphone: "iphone"
        case .custom: "rectangle.dashed"
        case .mac:
            if preset.name.hasPrefix("MacBook") { "macbook" }
            else if preset.name.hasPrefix("iMac") { "desktopcomputer" }
            else { "display" }
        }
    }
}
