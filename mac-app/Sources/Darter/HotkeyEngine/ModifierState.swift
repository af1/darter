import Cocoa

/// Catches modifiers that never reach our event tap.
///
/// Hyper-key remappers (Hyperkey, Karabiner) turn one physical key into
/// ⌃⌥⇧⌘ by adding those flags from their own event tap. When that tap sits
/// downstream of ours, the key arrives here bare -- a hyper-key chord and a
/// plain keypress are byte-identical, so the event's own flags can't tell
/// them apart. The live session state can: it reports the modifiers the
/// remapper is holding.
enum ModifierState {
    static func hasHiddenModifiers(shift: Bool, option: Bool, command: Bool, control: Bool) -> Bool {
        hidden(in: CGEventSource.flagsState(.combinedSessionState),
               shift: shift, option: option, command: command, control: control)
    }

    /// A single hidden modifier is a race, not a remapper.
    ///
    /// Reading live state asks what is held *now*, which isn't the instant
    /// the event was built. Press Shift and a key together and the key event
    /// can be stamped before Shift registers, leaving Shift hidden by this
    /// measure -- so treating one hidden modifier as a chord threw away real
    /// keypresses. A remapper hides its whole chord at once.
    private static let chordModifierMinimum = 2

    /// True when the session reports enough modifiers the event didn't carry
    /// to be somebody's chord. Caps Lock is excluded: it's a typing state,
    /// not part of one.
    static func hidden(in sessionFlags: CGEventFlags,
                       shift: Bool, option: Bool, command: Bool, control: Bool) -> Bool {
        let reported: [(CGEventFlags, Bool)] = [
            (.maskShift, shift),
            (.maskAlternate, option),
            (.maskCommand, command),
            (.maskControl, control),
        ]

        let hiddenCount = reported.filter { flag, carriedByEvent in
            sessionFlags.contains(flag) && !carriedByEvent
        }.count

        return hiddenCount >= chordModifierMinimum
    }
}
