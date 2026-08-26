import SwiftUI

struct SlidersTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Adjust Lightroom Classic's Develop sliders with your keyboard — no mouse, no clicking into fields.")
                    Text("With a photo open in the Develop module, press a slider's Decrease or Increase key to nudge it by its Amount. Hold a modifier from the Modifiers section for a smaller or larger step.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("Activate") {
                Toggle(isOn: Binding(
                    get: { viewModel.config.masterEnabled },
                    set: { viewModel.config.masterEnabled = $0; viewModel.commit() }
                )) {
                    Text("Enabled (Shift + \(KeyCode.displayName(for: viewModel.config.masterToggleKey.keyCode)))")
                }
            }

            Section("Modifiers") {
                HStack {
                    Text("Smaller change: hold")
                    Picker("", selection: Binding(
                        get: { viewModel.config.smallMultiplierModifier },
                        set: { viewModel.config.smallMultiplierModifier = $0; viewModel.commit() }
                    )) {
                        ForEach(ModifierChoice.allCases, id: \.self) { Text($0.displayName) }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    Spacer()
                    Text("multiplier:")
                    MultiplierStepperField(value: Binding(
                        get: { viewModel.config.smallMultiplier },
                        set: { viewModel.config.smallMultiplier = $0; viewModel.commit() }
                    ), range: 0.1...0.9)
                }
                HStack {
                    Text("Larger change: hold")
                    Picker("", selection: Binding(
                        get: { viewModel.config.largeMultiplierModifier },
                        set: { viewModel.config.largeMultiplierModifier = $0; viewModel.commit() }
                    )) {
                        ForEach(ModifierChoice.allCases, id: \.self) { Text($0.displayName) }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    Spacer()
                    Text("multiplier:")
                    MultiplierStepperField(value: Binding(
                        get: { viewModel.config.largeMultiplier },
                        set: { viewModel.config.largeMultiplier = $0; viewModel.commit() }
                    ), range: 1.1...5)
                }

                Text("A modifier set to None (or not listed here) is never intercepted — combos like Option+S stay available to other apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sliders") {
                Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
                    GridRow {
                        Text("Slider").bold()
                        Text("Amount").bold()
                        Text("Decrease").bold()
                        Text("Increase").bold()
                    }
                    ForEach(viewModel.config.sliders) { slider in
                        GridRow {
                            Text(slider.displayName)
                            TextField("", value: Binding(
                                get: { slider.amount },
                                set: { viewModel.setAmount($0, for: slider) }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            KeyCaptureField(binding: Binding(
                                get: { slider.decreaseKey },
                                set: { viewModel.setDecreaseKey($0, for: slider) }
                            ), stealPulse: viewModel.stolenPulses[SettingsViewModel.decSlot(slider)])
                            KeyCaptureField(binding: Binding(
                                get: { slider.increaseKey },
                                set: { viewModel.setIncreaseKey($0, for: slider) }
                            ), stealPulse: viewModel.stolenPulses[SettingsViewModel.incSlot(slider)])
                        }
                    }
                }
                .padding(.vertical, 4)
            }

        }
        .formStyle(.grouped)
    }
}
