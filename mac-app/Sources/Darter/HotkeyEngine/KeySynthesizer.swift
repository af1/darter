import CoreGraphics

/// Posts a synthetic keystroke directly to a target process. Used for the
/// rare Lightroom action that has neither an SDK hook nor a pressable AX
/// button -- e.g. "rotate crop aspect", which only exists as the native X
/// shortcut while the crop overlay is open.
enum KeySynthesizer {
    /// Callers must announce the keystroke to the event tap FIRST via
    /// EventTapManager.expectSyntheticKey(_:) -- otherwise the tap will
    /// intercept our own event and fire whatever that key is bound to.
    /// (Marker-based self-identification via eventSourceUserData was tried
    /// and did not survive the trip through the event system.)
    static func postKey(_ keyCode: CGKeyCode, toPid pid: pid_t) {
        // Private event source + explicitly empty flags: the user is
        // physically holding modifiers at this moment (the shortcut that
        // triggered us), and those must not contaminate the synthesized
        // event -- Lightroom treats Shift+X differently from X.
        let source = CGEventSource(stateID: .privateState)
        for isKeyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isKeyDown) else { continue }
            event.flags = []
            event.postToPid(pid)
        }
    }
}
