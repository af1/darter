import Foundation

enum HotkeyAction: Equatable {
    /// relativeDelta is the step to use for non-raw files (JPG/TIFF), sent
    /// alongside the raw delta so the plugin can pick per file format. nil
    /// for sliders with no relative override.
    case adjustSlider(paramName: String, delta: Double, relativeDelta: Double?)
    case activateTool(toolName: String)
    case applyPreset(folder: String, name: String)
    case toggleMasterEnabled
}

/// Pure function: given the current config and a key event, decide what (if
/// anything) should happen. Deliberately scoped to only fire while
/// Lightroom Classic is the frontmost app -- otherwise a bound key like "Q"
/// or "N" would hijack ordinary typing in every other app on the system.
enum HotkeyMatcher {
    static let lightroomBundleID = "com.adobe.LightroomClassicCC7"

    /// Cmd+digit -> which preset slot. Maps digit key codes to the slot
    /// digit value (1-9, and 0 for the tenth slot).
    private static let digitKeyCodes: [UInt16: Int] = [
        KeyCode.one: 1, KeyCode.two: 2, KeyCode.three: 3, KeyCode.four: 4,
        KeyCode.five: 5, KeyCode.six: 6, KeyCode.seven: 7, KeyCode.eight: 8,
        KeyCode.nine: 9, KeyCode.zero: 0,
    ]

    static func match(
        config: AppConfig,
        keyCode: UInt16,
        shiftHeld: Bool,
        optionHeld: Bool,
        commandHeld: Bool,
        controlHeld: Bool,
        frontmostBundleID: String?
    ) -> HotkeyAction? {
        guard frontmostBundleID == lightroomBundleID else { return nil }

        // Cmd+digit -> apply preset. Handled first, and only for EXACTLY
        // Cmd (no Shift/Option/Control), so it can't collide with either the
        // plain-key slider/tool bindings below or Lightroom's own
        // Cmd+Shift/Cmd+Option shortcuts, which must pass through untouched.
        if commandHeld, !controlHeld, !optionHeld, !shiftHeld {
            guard config.masterEnabled else { return nil }
            if let digit = digitKeyCodes[keyCode],
               let slot = config.presetSlots.first(where: { $0.digit == digit && $0.hasPreset }),
               let folder = slot.folder, let name = slot.presetName {
                return .applyPreset(folder: folder, name: name)
            }
            return nil
        }

        // Everything below is for non-Command keys. (Control is allowed
        // through to matching because it can be configured as a multiplier
        // modifier; anything else Control-chorded falls out in keyMatches.)
        guard !commandHeld else { return nil }

        let toggle = config.masterToggleKey
        if keyCode == toggle.keyCode
            && shiftHeld == toggle.requiresShift
            && optionHeld == toggle.requiresOption
            && !controlHeld {
            return .toggleMasterEnabled
        }

        guard config.masterEnabled else { return nil }

        // All bindings that match this event compete, and the most SPECIFIC
        // one wins: a binding that requires Shift (e.g. Shift+Tab -> rotate
        // crop aspect) beats a loose binding on the same key (Tab -> open
        // crop tool), which would otherwise match first purely by list order
        // since loose bindings also match when extra modifiers are held.
        var best: (action: HotkeyAction, specificity: Int)?

        func consider(_ binding: KeyBinding, _ action: HotkeyAction) {
            guard keyMatches(binding, config: config, keyCode: keyCode,
                             shiftHeld: shiftHeld, optionHeld: optionHeld, controlHeld: controlHeld) else { return }
            let specificity = (binding.requiresShift ? 1 : 0) + (binding.requiresOption ? 1 : 0)
            if best == nil || specificity > best!.specificity {
                best = (action, specificity)
            }
        }

        for slider in config.sliders {
            if let dec = slider.decreaseKey {
                let m = multiplier(config: config, binding: dec, shiftHeld: shiftHeld, optionHeld: optionHeld, controlHeld: controlHeld)
                consider(dec, .adjustSlider(paramName: slider.paramName, delta: -slider.amount * m,
                                            relativeDelta: slider.relativeAmount.map { -$0 * m }))
            }
            if let inc = slider.increaseKey {
                let m = multiplier(config: config, binding: inc, shiftHeld: shiftHeld, optionHeld: optionHeld, controlHeld: controlHeld)
                consider(inc, .adjustSlider(paramName: slider.paramName, delta: slider.amount * m,
                                            relativeDelta: slider.relativeAmount.map { $0 * m }))
            }
        }

        for tool in config.tools {
            if let key = tool.key {
                consider(key, .activateTool(toolName: tool.toolName))
            }
        }

        return best?.action
    }

    /// STRICT matching: every held modifier must be accounted for -- either
    /// required by the binding itself, or designated as one of the two
    /// multiplier modifiers in config. Anything else (e.g. Option+S when the
    /// small multiplier is set to Control) is somebody else's shortcut and
    /// must pass through to the system untouched.
    private static func keyMatches(_ binding: KeyBinding, config: AppConfig, keyCode: UInt16,
                                   shiftHeld: Bool, optionHeld: Bool, controlHeld: Bool) -> Bool {
        guard binding.keyCode == keyCode else { return false }
        if binding.requiresShift && !shiftHeld { return false }
        if binding.requiresOption && !optionHeld { return false }

        let multiplierModifiers: Set<ModifierChoice> = [config.smallMultiplierModifier, config.largeMultiplierModifier]
        if shiftHeld && !binding.requiresShift && !multiplierModifiers.contains(.shift) { return false }
        if optionHeld && !binding.requiresOption && !multiplierModifiers.contains(.option) { return false }
        if controlHeld && !multiplierModifiers.contains(.control) { return false }
        return true
    }

    /// A held multiplier modifier only scales the amount when it is NOT part
    /// of the binding's identity -- for a binding that itself requires
    /// Shift, a held Shift selects the binding rather than multiplying it.
    /// Small takes precedence if both multiplier modifiers are held.
    private static func multiplier(config: AppConfig, binding: KeyBinding,
                                   shiftHeld: Bool, optionHeld: Bool, controlHeld: Bool) -> Double {
        func active(_ choice: ModifierChoice) -> Bool {
            switch choice {
            case .none: return false
            case .shift: return shiftHeld && !binding.requiresShift
            case .option: return optionHeld && !binding.requiresOption
            case .control: return controlHeld
            }
        }
        if active(config.smallMultiplierModifier) { return config.smallMultiplier }
        if active(config.largeMultiplierModifier) { return config.largeMultiplier }
        return 1.0
    }
}
