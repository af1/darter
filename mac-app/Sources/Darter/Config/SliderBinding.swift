import Foundation

struct SliderBinding: Codable, Identifiable, Equatable {
    var id: String { paramName }
    var displayName: String
    /// Must match a key in the Lightroom plugin's CommandHandler.PARAM_MAP.
    var paramName: String
    var amount: Double
    /// Step used for non-raw files (JPG/TIFF/PSD/PNG). Only meaningful for
    /// white-balance sliders: Temperature/Tint are absolute (Kelvin) on raw
    /// files but a relative -100…100 scale on non-raw ones, where the raw
    /// step is far too large. nil means "same amount regardless of format".
    var relativeAmount: Double? = nil
    var decreaseKey: KeyBinding?
    var increaseKey: KeyBinding?
}
