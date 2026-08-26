import Foundation

struct AppConfig: Equatable {
    var sliders: [SliderBinding]
    var tools: [ToolBinding]
    var presetSlots: [PresetSlot]
    var masterToggleKey: KeyBinding
    var masterEnabled: Bool
    var smallMultiplier: Double
    var largeMultiplier: Double
    var smallMultiplierModifier: ModifierChoice
    var largeMultiplierModifier: ModifierChoice
    /// How held left/right arrows are handled -- see Coordinator's arrow-key
    /// MARK.
    var arrowNavMode: ArrowNavMode
    /// Hold-scroll rate for `.paced` mode only; `.native` uses Lightroom's
    /// own repeat speed.
    var arrowNavPhotosPerSecond: Double

    static let `default` = AppConfig(
        sliders: [
            SliderBinding(displayName: "Temperature", paramName: "Temperature", amount: 100, relativeAmount: 3,
                           decreaseKey: KeyBinding(keyCode: KeyCode.q), increaseKey: KeyBinding(keyCode: KeyCode.w)),
            SliderBinding(displayName: "Tint", paramName: "Tint", amount: 3, relativeAmount: 3,
                           decreaseKey: KeyBinding(keyCode: KeyCode.a), increaseKey: KeyBinding(keyCode: KeyCode.s)),
            SliderBinding(displayName: "Exposure", paramName: "Exposure", amount: 0.1,
                           decreaseKey: KeyBinding(keyCode: KeyCode.e), increaseKey: KeyBinding(keyCode: KeyCode.r)),
            SliderBinding(displayName: "Contrast", paramName: "Contrast", amount: 10,
                           decreaseKey: KeyBinding(keyCode: KeyCode.d), increaseKey: KeyBinding(keyCode: KeyCode.f)),
            SliderBinding(displayName: "Highlights", paramName: "Highlights", amount: 10,
                           decreaseKey: KeyBinding(keyCode: KeyCode.z), increaseKey: KeyBinding(keyCode: KeyCode.x)),
            SliderBinding(displayName: "Shadows", paramName: "Shadows", amount: 10,
                           decreaseKey: KeyBinding(keyCode: KeyCode.c), increaseKey: KeyBinding(keyCode: KeyCode.v)),
            SliderBinding(displayName: "Saturation", paramName: "Saturation", amount: 10,
                           decreaseKey: KeyBinding(keyCode: KeyCode.b), increaseKey: KeyBinding(keyCode: KeyCode.n)),
            SliderBinding(displayName: "Crop Angle", paramName: "CropAngle", amount: 0.5,
                           decreaseKey: KeyBinding(keyCode: KeyCode.minus), increaseKey: KeyBinding(keyCode: KeyCode.equals)),
        ],
        tools: [
            ToolBinding(displayName: "Crop", toolName: "Crop", key: KeyBinding(keyCode: KeyCode.tab)),
            ToolBinding(displayName: "Auto Straighten", toolName: "AutoStraighten", key: KeyBinding(keyCode: KeyCode.l)),
            // Only acts while the crop overlay is open (synthesizes
            // Lightroom's native X shortcut, guarded by an is-crop-open
            // check -- see Coordinator.rotateCropAspect).
            ToolBinding(displayName: "Rotate Crop Aspect", toolName: "RotateCropAspect",
                        key: KeyBinding(keyCode: KeyCode.tab, requiresShift: true)),
            // Both synthesize Lightroom's native shortcut (W / I) -- neither
            // has an SDK hook. The plain-I binding takes over I's native
            // meaning, so the info overlay moves to Shift+I.
            ToolBinding(displayName: "White Balance Picker", toolName: "WhiteBalancePicker",
                        key: KeyBinding(keyCode: KeyCode.i)),
            ToolBinding(displayName: "Info Overlay", toolName: "InfoOverlay",
                        key: KeyBinding(keyCode: KeyCode.i, requiresShift: true)),
            // Unbound by default -- set a key in Settings to use them.
            ToolBinding(displayName: "Reset Crop", toolName: "ResetCrop", key: nil),
            ToolBinding(displayName: "Remove", toolName: "Remove", key: nil),
            ToolBinding(displayName: "Masking", toolName: "Masking", key: nil),
            // Add more here later (Brush -> "localized", Gradient -> "gradient",
            // Radial Filter -> "circularGradient", ...) as long as
            // CommandHandler.lua's TOOL_MAP gets a matching entry.
        ],
        presetSlots: PresetSlot.emptySlots,
        masterToggleKey: KeyBinding(keyCode: KeyCode.escape, requiresShift: true),
        masterEnabled: true,
        smallMultiplier: 0.5,
        largeMultiplier: 2.5,
        smallMultiplierModifier: .option,
        largeMultiplierModifier: .shift,
        arrowNavMode: .paced,
        arrowNavPhotosPerSecond: 40
    )
}

extension AppConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case sliders, tools, presetSlots, masterToggleKey, masterEnabled, smallMultiplier, largeMultiplier
        case smallMultiplierModifier, largeMultiplierModifier
        case arrowNavMode, arrowNavPhotosPerSecond
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sliders = try container.decode([SliderBinding].self, forKey: .sliders)
        // Older saved configs predate the "tools" section entirely.
        tools = try container.decodeIfPresent([ToolBinding].self, forKey: .tools) ?? AppConfig.default.tools
        // Older configs predate preset slots; seed the 10 empty ones.
        presetSlots = try container.decodeIfPresent([PresetSlot].self, forKey: .presetSlots) ?? PresetSlot.emptySlots
        masterToggleKey = try container.decode(KeyBinding.self, forKey: .masterToggleKey)
        masterEnabled = try container.decode(Bool.self, forKey: .masterEnabled)
        smallMultiplier = try container.decode(Double.self, forKey: .smallMultiplier)
        largeMultiplier = try container.decode(Double.self, forKey: .largeMultiplier)
        // Older configs predate configurable multiplier modifiers.
        smallMultiplierModifier = try container.decodeIfPresent(ModifierChoice.self, forKey: .smallMultiplierModifier) ?? .option
        largeMultiplierModifier = try container.decodeIfPresent(ModifierChoice.self, forKey: .largeMultiplierModifier) ?? .shift
        arrowNavMode = try container.decodeIfPresent(ArrowNavMode.self, forKey: .arrowNavMode) ?? .paced
        arrowNavPhotosPerSecond = try container.decodeIfPresent(Double.self, forKey: .arrowNavPhotosPerSecond) ?? 40
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sliders, forKey: .sliders)
        try container.encode(tools, forKey: .tools)
        try container.encode(presetSlots, forKey: .presetSlots)
        try container.encode(masterToggleKey, forKey: .masterToggleKey)
        try container.encode(masterEnabled, forKey: .masterEnabled)
        try container.encode(smallMultiplier, forKey: .smallMultiplier)
        try container.encode(largeMultiplier, forKey: .largeMultiplier)
        try container.encode(smallMultiplierModifier, forKey: .smallMultiplierModifier)
        try container.encode(largeMultiplierModifier, forKey: .largeMultiplierModifier)
        try container.encode(arrowNavMode, forKey: .arrowNavMode)
        try container.encode(arrowNavPhotosPerSecond, forKey: .arrowNavPhotosPerSecond)
    }
}
