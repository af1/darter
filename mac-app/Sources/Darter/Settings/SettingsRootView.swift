import SwiftUI

/// Top-level settings content: a segmented control over the Sliders and
/// Presets pages. Uses a plain segmented Picker rather than a TabView to
/// avoid TabView's gray chrome strip behind the tabs.
struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel
    /// Called after the visible tab changes so the window controller can
    /// re-measure the new tab's content and resize the window to fit it
    /// (each tab has a different natural height).
    var onTabChanged: (() -> Void)?

    private enum Tab: String, CaseIterable {
        case sliders = "Sliders"
        case tools = "Tools"
        case presets = "Presets"
    }
    @State private var tab: Tab = .sliders

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.vertical, 10)
            .onChange(of: tab) { _ in onTabChanged?() }

            Divider()

            switch tab {
            case .sliders:
                SlidersTabView(viewModel: viewModel)
            case .tools:
                ToolsTabView(viewModel: viewModel)
            case .presets:
                PresetsTabView(viewModel: viewModel)
            }

            Divider()

            HStack {
                Menu("Starter Profiles") {
                    ForEach(StarterProfiles.all) { profile in
                        Button(profile.name) { viewModel.loadStarterProfile(profile) }
                    }
                }
                .frame(width: 150)
                Spacer()
                Button("Import Settings…") { viewModel.importSettings() }
                Button("Export Settings…") { viewModel.exportSettings() }
            }
            .padding(10)
        }
        // Width is fixed; height is decided by SettingsWindowController,
        // which measures the Form's actual content and sizes the window so
        // nothing needs to scroll.
        .frame(width: 600)
    }
}
