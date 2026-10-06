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

    /// True when the session reports a modifier the event didn't carry.
    /// Caps Lock is excluded: it's a typing state, not part of a chord.
    static func hidden(in sessionFlags: CGEventFlags,
                       shift: Bool, option: Bool, command: Bool, control: Bool) -> Bool {
        let reported: [(CGEventFlags, Bool)] = [
            (.maskShift, shift),
            (.maskAlternate, option),
            (.maskCommand, command),
            (.maskControl, control),
        ]

        return reported.contains { flag, carriedByEvent in
            sessionFlags.contains(flag) && !carriedByEvent
        }
    }
}
