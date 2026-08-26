import Foundation

/// A key + which modifiers must be held for this exact binding to match.
/// For slider decrease/increase keys, both flags are normally false --
/// Option/Shift are instead read separately at match time to scale the
/// adjustment amount, not to select which binding fires. The master
/// activate/deactivate toggle (Shift+Esc) is the one binding that actually
/// requires a modifier as part of its identity.
struct KeyBinding: Codable, Equatable, Hashable {
    var keyCode: UInt16
    var requiresShift: Bool
    var requiresOption: Bool

    init(keyCode: UInt16, requiresShift: Bool = false, requiresOption: Bool = false) {
        self.keyCode = keyCode
        self.requiresShift = requiresShift
        self.requiresOption = requiresOption
    }
}
