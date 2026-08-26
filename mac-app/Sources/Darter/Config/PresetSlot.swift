import Foundation

/// One Cmd+<digit> slot that applies a Lightroom develop preset. Ten fixed
/// slots exist (digits 1-9 and 0); each may or may not have a preset chosen.
/// A preset is identified by folder + name together, because the same preset
/// name can appear in more than one folder.
struct PresetSlot: Codable, Identifiable, Equatable {
    /// 1...9, or 0 for the tenth slot. Also the identity.
    var digit: Int
    var folder: String?
    var presetName: String?

    var id: Int { digit }
    var hasPreset: Bool { folder != nil && presetName != nil }

    /// Cmd+1 ... Cmd+9, Cmd+0 -- the label shown next to the slot.
    var shortcutLabel: String { "⌘ \(digit)" }

    static let allDigits = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]

    static var emptySlots: [PresetSlot] {
        allDigits.map { PresetSlot(digit: $0, folder: nil, presetName: nil) }
    }
}
