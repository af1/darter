import Foundation

/// A single bindable key that just activates a Develop tool (Crop, Brush,
/// etc.) -- no amount, no decrease/increase, unlike SliderBinding.
struct ToolBinding: Codable, Identifiable, Equatable {
    var id: String { toolName }
    var displayName: String
    /// Must match a key in the Lightroom plugin's CommandHandler.TOOL_MAP.
    var toolName: String
    var key: KeyBinding?
}
