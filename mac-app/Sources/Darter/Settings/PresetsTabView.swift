import SwiftUI

/// Cmd+1 ... Cmd+0 slots, each applying a chosen Develop preset. The preset
/// list comes from Lightroom via the plugin (Refresh re-exports it).
struct PresetsTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("Press ⌘ + a number in Lightroom to apply the assigned preset.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.availablePresets.isEmpty {
                    Text("No presets loaded yet. Open Lightroom Classic, then click Refresh.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Spacer()
                    Button {
                        viewModel.refreshPresetsFromLightroom()
                    } label: {
                        if viewModel.isRefreshingPresets {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Refresh from Lightroom", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isRefreshingPresets)
                }
            }

            Section("Preset Slots") {
                ForEach(viewModel.config.presetSlots) { slot in
                    HStack {
                        Text(slot.shortcutLabel)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 40, alignment: .leading)
                        Spacer()
                        presetPicker(for: slot)
                            .frame(maxWidth: 380)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func presetPicker(for slot: PresetSlot) -> some View {
        PresetPickerButton(
            current: currentPreset(for: slot),
            presets: viewModel.availablePresets,
            onSelect: { viewModel.setPreset($0, forDigit: slot.digit) }
        )
    }

    private func currentPreset(for slot: PresetSlot) -> AvailablePreset? {
        guard let folder = slot.folder, let name = slot.presetName else { return nil }
        return AvailablePreset(folder: folder, name: name)
    }
}
