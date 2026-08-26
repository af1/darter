import SwiftUI

/// Trigger-only bindings (Crop, Auto Straighten, and later Brush/Gradient/
/// etc.) -- just a tool name and a single key, no amount or decrease/
/// increase columns since there's nothing to scale. Rendered as the content
/// of the "Open Tool" Section in SlidersTabView.
struct ToolsSectionView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
            GridRow {
                Text("Tool").bold()
                Text("Key").bold()
            }
            ForEach(viewModel.config.tools) { tool in
                GridRow {
                    Text(tool.displayName)
                    KeyCaptureField(binding: Binding(
                        get: { tool.key },
                        set: { viewModel.setToolKey($0, for: tool) }
                    ), stealPulse: viewModel.stolenPulses[SettingsViewModel.toolSlot(tool)])
                }
            }
        }
        .padding(.vertical, 4)
    }
}
