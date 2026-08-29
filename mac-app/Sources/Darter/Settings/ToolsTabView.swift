import SwiftUI

/// Secondary functions, split out of the Sliders tab to keep it compact:
/// tool-opening keys, hold-scroll photo navigation, and the non-raw white
/// balance steps.
struct ToolsTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Open Tool") {
                ToolsSectionView(viewModel: viewModel)
            }

            Section("Photo Navigation") {
                Picker("Holding ← or →:", selection: Binding(
                    get: { viewModel.config.arrowNavMode },
                    set: { viewModel.config.arrowNavMode = $0; viewModel.commit() }
                )) {
                    ForEach(ArrowNavMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                switch viewModel.config.arrowNavMode {
                case .native:
                    Text("Lightroom handles held arrows itself, at its own speed. Note that Lightroom can keep scrolling for several seconds after you let go — it queues photos faster than it can render them. Building Standard-Sized Previews reduces this; Paced avoids it entirely.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .paced:
                    Text("Darter advances photos itself while the arrow is held. Keep this at or below the rate Lightroom can actually render — anything faster queues up and keeps scrolling after you let go. Around 2–3/sec suits uncached raw files; build Standard-Sized Previews to go faster.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        Text("Hold-scroll speed")
                        Slider(value: Binding(
                            get: { viewModel.config.arrowNavPhotosPerSecond },
                            set: { viewModel.config.arrowNavPhotosPerSecond = $0; viewModel.commit() }
                        ), in: 1...30, step: 1)
                        Text("\(Int(viewModel.config.arrowNavPhotosPerSecond))/sec")
                            .monospacedDigit()
                            .frame(width: 55, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("White Balance — non-raw files") {
                Text("On JPG, TIFF and other non-raw files, Temperature and Tint use a relative −100…100 scale instead of Kelvin, so they take a much smaller step. The main Amount on the Sliders tab is used for raw files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(viewModel.config.sliders.filter { $0.relativeAmount != nil }) { slider in
                    HStack {
                        Text("\(slider.displayName) step")
                        Spacer()
                        TextField("", value: Binding(
                            get: { slider.relativeAmount ?? 0 },
                            set: { viewModel.setRelativeAmount($0, for: slider) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
