import BRDShared
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            if Edition.isPro {
                PresetsTab().tabItem { Label("Presets", systemImage: "list.bullet") }
                CustomTab().tabItem { Label("Custom", systemImage: "slider.horizontal.3") }
            } else {
                DeviceTab().tabItem { Label("Device", systemImage: "macbook.and.ipad") }
                ProTab().tabItem { Label("Pro", systemImage: "sparkles") }
            }
        }
        .frame(width: 520, height: 520)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Environment(ConfigStore.self) private var store
    @Environment(HelperConnection.self) private var helper

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { helper.isRunning }, set: { helper.setEnabled($0) })) {
                    Text("Enable BetterRemoteDisplay")
                        .font(.title3.weight(.medium))
                    Text(helper.isRunning
                         ? "Running in the menu bar. You can close this window."
                         : "Turn on to add the resolution switcher to the menu bar.")
                }
                .toggleStyle(.switch)
                .controlSize(.large)
                if helper.isRunning {
                    Toggle("Start at login", isOn: Binding(
                        get: { helper.startsAtLogin }, set: { helper.setStartsAtLogin($0) }
                    ))
                }
                if let error = helper.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section("Virtual Display") {
                Toggle("Virtual display", isOn: binding(\.enabled))
                LabeledContent("Resolution") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.config.size.label)
                            .monospacedDigit()
                        if let preset = store.config.currentPreset {
                            Text([preset.name, preset.variant].compactMap(\.self).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Toggle(isOn: binding(\.hiDPI)) {
                    Text("HiDPI")
                    Text(store.config.size.supportsHiDPI
                         ? "Render at 2x so the remote session is sharp on a Retina screen."
                         : "Not available above \(DisplaySize.maxPixels / 2) points.")
                }
                .disabled(!store.config.size.supportsHiDPI)
            }
            .disabled(!helper.isRunning)

            Section {
                LabeledContent("Edition") {
                    if Edition.isPro {
                        Text("Pro")
                    } else {
                        Link("Free · Get Pro", destination: Edition.upgradeURL)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { helper.refresh() }
    }

    private func binding(_ keyPath: WritableKeyPath<Config, Bool>) -> Binding<Bool> {
        Binding(get: { store.config[keyPath: keyPath] },
                set: { value in store.update { $0[keyPath: keyPath] = value } })
    }
}

// MARK: - Free edition

/// The free edition works with one device. This is where you say which.
private struct DeviceTab: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        Form {
            ForEach([DeviceCategory.mac, .ipad, .iphone]) { category in
                Section(category.title) {
                    ForEach(Presets.deviceNames(in: category), id: \.self) { name in
                        Button {
                            choose(name)
                        } label: {
                            HStack {
                                Text(name)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                                    .opacity(store.config.device == name ? 1 : 0)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section {
            } footer: {
                Text("The menu bar offers this device’s resolutions. MacBook sizes exclude the notch. iPhone sizes are the screen’s pixels at 2x, because macOS can’t go as small as an iPhone’s own point size.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }

    private func choose(_ name: String) {
        store.update {
            $0.device = name
            // Move to the new device's first (default) mode, keeping the current orientation.
            guard let size = $0.devicePresets.first?.size else { return }
            $0.size = $0.size.isPortrait == size.isPortrait ? size : size.rotated
        }
    }
}

private struct ProTab: View {
    var body: some View {
        ContentUnavailableView {
            Label("BetterRemoteDisplay Pro", systemImage: "sparkles")
        } description: {
            Text("Switch between any number of devices from the menu bar, and add your own custom resolutions. One-time purchase.")
        } actions: {
            Link("Get Pro", destination: Edition.upgradeURL)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

// MARK: - Presets

private struct PresetsTab: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        Form {
            ForEach([DeviceCategory.mac, .ipad, .iphone]) { category in
                Section(category.title) {
                    ForEach(store.config.presets(in: category)) { preset in
                        Toggle(isOn: Binding(
                            get: { store.config.isVisible(preset) },
                            set: { shown in
                                store.update {
                                    // Store only what differs from the built-in default.
                                    $0.visibility[preset.id] = shown == preset.showsByDefault ? nil : shown
                                }
                            }
                        )) {
                            PresetLabel(preset: preset)
                        }
                    }
                }
            }
            Section {
                Button("Restore Defaults") { store.update { $0.visibility = [:] } }
                    .disabled(store.config.visibility.isEmpty)
            } footer: {
                Text("Checked presets appear in the menu bar. Resolutions are in points. MacBook sizes exclude the notch. iPhone sizes are the screen’s pixels at 2x, because macOS can’t go as small as an iPhone’s own point size.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PresetLabel: View {
    let preset: DisplayPreset

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                if let variant = preset.variant {
                    Text(variant)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(preset.size.label)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Custom

private struct CustomTab: View {
    @Environment(ConfigStore.self) private var store
    @State private var name = ""
    @State private var width: Int?
    @State private var height: Int?

    private var draft: DisplaySize? {
        guard let width, let height else { return nil }
        let size = DisplaySize(width, height)
        return size.isValid ? size : nil
    }

    var body: some View {
        Form {
            Section("New Resolution") {
                TextField("Name", text: $name, prompt: Text("Optional"))
                LabeledContent("Size") {
                    HStack(spacing: 6) {
                        TextField("Width", value: $width, format: .number.grouping(.never), prompt: Text("Width"))
                        Text("×").foregroundStyle(.secondary)
                        TextField("Height", value: $height, format: .number.grouping(.never), prompt: Text("Height"))
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .monospacedDigit()
                }
                HStack {
                    Text("In points, up to \(DisplaySize.maxPixels) per side. macOS rejects desktops smaller than about 960 × 540.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add", action: add)
                        .disabled(draft == nil)
                        .keyboardShortcut(.defaultAction)
                }
            }

            Section("Custom Resolutions") {
                if store.config.customs.isEmpty {
                    Text("None yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.config.customs) { custom in
                    HStack {
                        PresetLabel(preset: custom.preset)
                        Button("Use") {
                            store.update { $0.size = custom.size; $0.enabled = true }
                        }
                        .disabled(store.config.enabled && store.config.size == custom.size)
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            store.update { $0.customs.removeAll { $0.id == custom.id } }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func add() {
        guard let draft else { return }
        let custom = CustomResolution(name: name.trimmingCharacters(in: .whitespaces), size: draft)
        store.update { $0.customs.append(custom) }
        name = ""
        width = nil
        height = nil
    }
}
