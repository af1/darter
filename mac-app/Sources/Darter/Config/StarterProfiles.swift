import Foundation

/// Bundled, original starter layouts a new user can load with one click.
/// These are our own designs (not reproductions of any other product's
/// layout) -- differentiated by editing style so each is genuinely useful.
struct StarterProfile: Identifiable {
    let name: String
    let detail: String
    /// A full AppConfig, but only its sliders/tools/multipliers/toggle are
    /// used on load -- presetSlots and masterEnabled are kept from the
    /// user's current config (see Coordinator.loadStarterProfile).
    let config: AppConfig
    var id: String { name }
}

enum StarterProfiles {
    static let all: [StarterProfile] = [presetA, bigSteps, columns]

    private static let presetA = StarterProfile(
        name: "Preset A",
        detail: "The maker's own layout — a balanced all-around starting point. Each slider's decrease and increase keys sit side by side.",
        config: .default
    )

    private static let bigSteps: StarterProfile = {
        var config = AppConfig.default
        let amounts: [String: Double] = [
            "Temperature": 200, "Tint": 6, "Exposure": 0.25, "Contrast": 20,
            "Highlights": 20, "Shadows": 20, "Saturation": 20, "CropAngle": 1.0,
        ]
        for i in config.sliders.indices {
            if let amount = amounts[config.sliders[i].paramName] {
                config.sliders[i].amount = amount
            }
        }
        return StarterProfile(
            name: "Big Steps",
            detail: "Same keys as Default but larger adjustments — good for getting a feel for what each slider does.",
            config: config
        )
    }()

    // Vertical pairs: the increase key sits directly above the decrease key,
    // so "press higher = more" reads spatially. Spans both hands.
    private static let columns: StarterProfile = {
        var config = AppConfig.default
        let pairs: [String: (dec: UInt16, inc: UInt16)] = [
            "Temperature": (KeyCode.a, KeyCode.q),
            "Tint":        (KeyCode.s, KeyCode.w),
            "Exposure":    (KeyCode.d, KeyCode.e),
            "Contrast":    (KeyCode.f, KeyCode.r),
            "Highlights":  (KeyCode.g, KeyCode.t),
            "Shadows":     (KeyCode.h, KeyCode.y),
            "Saturation":  (KeyCode.j, KeyCode.u),
            "CropAngle":   (KeyCode.k, KeyCode.i),
        ]
        for i in config.sliders.indices {
            if let pair = pairs[config.sliders[i].paramName] {
                config.sliders[i].decreaseKey = KeyBinding(keyCode: pair.dec)
                config.sliders[i].increaseKey = KeyBinding(keyCode: pair.inc)
            }
        }
        return StarterProfile(
            name: "Columns",
            detail: "Decrease on the home row, increase directly above it — press higher for more.",
            config: config
        )
    }()
}
