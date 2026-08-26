import Foundation

/// Which physical modifier scales an adjustment (the "smaller"/"larger"
/// multiplier feature). Configurable so bound-key combos can be released to
/// other apps -- e.g. a window manager on Option+S: set the small multiplier
/// to Control or None and Option+<bound key> passes through untouched.
enum ModifierChoice: String, Codable, CaseIterable, Equatable {
    case none
    case shift
    case option
    case control

    var displayName: String {
        switch self {
        case .none: return "None"
        case .shift: return "⇧ Shift"
        case .option: return "⌥ Option"
        case .control: return "⌃ Control"
        }
    }
}
