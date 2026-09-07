import ApplicationServices
import Foundation

/// Decides whether a matched key should be let through to the system instead
/// of intercepted -- because keyboard focus isn't really in Lightroom's photo
/// view. Three cases:
///   1. An overlay launcher (Raycast, Spotlight, Alfred) is floating over
///      Lightroom. These use non-activating panels, so
///      NSWorkspace.frontmostApplication still reports Lightroom -- but the
///      keystroke belongs to the overlay's search field.
///   2. A text field inside Lightroom itself is focused (keyword box, filter
///      bar, rename, the Help menu search).
///   3. A modal dialog is open (Edit Capture Time, Export, rename...).
///
/// All are answered from one query against the SYSTEM-WIDE focused UI element
/// (who owns keyboard focus right now), so this stays a single AX round trip
/// -- and it's only made after HotkeyMatcher already matched a bound key,
/// never on ordinary typing, so there's no per-keystroke cost.
enum FocusedElementChecker {
    private static let textInputRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        kAXSearchFieldSubrole as String,
    ]

    private static let dialogSubroles: Set<String> = [
        kAXDialogSubrole as String,
        kAXSystemDialogSubrole as String,
    ]

    /// Not exposed by the SDK as a constant.
    private static let modalAttribute = "AXModal"

    /// What the AX layer reports about whoever owns keyboard focus. Split out
    /// so the decision below is a pure function over plain values, testable
    /// without a live Lightroom window.
    struct FocusSnapshot: Equatable {
        let pid: pid_t
        let role: String?
        let subrole: String?
        let windowSubrole: String?
        let windowIsModal: Bool
    }

    static func shouldPassThrough(lightroomPID: pid_t) -> Bool {
        // Nothing reports keyboard focus. NSWorkspace already says Lightroom
        // is frontmost, so treat it as ours and intercept.
        guard let focus = currentFocus() else {
            return false
        }

        return shouldPassThrough(focus: focus, lightroomPID: lightroomPID)
    }

    static func shouldPassThrough(focus: FocusSnapshot, lightroomPID: pid_t) -> Bool {
        // Focus is in a different process (an overlay floating over
        // Lightroom) -- the keystroke is theirs.
        if focus.pid != lightroomPID {
            return true
        }

        // A modal dialog owns the keyboard. Lightroom's own dialogs don't
        // publish focus down to their text fields -- Edit Capture Time
        // reports the focused element as a radio button while the user is
        // typing a date -- so the role check below can't see them. Develop
        // shortcuts mean nothing while a dialog is up, so keep out entirely.
        if focus.windowIsModal {
            return true
        }
        if let windowSubrole = focus.windowSubrole, dialogSubroles.contains(windowSubrole) {
            return true
        }

        // A text input (keyword box, filter, search) -- let the user type.
        // Some search fields report role=AXTextField and distinguish
        // themselves by subrole, so check both.
        if let role = focus.role, textInputRoles.contains(role) {
            return true
        }
        if let subrole = focus.subrole, textInputRoles.contains(subrole) {
            return true
        }

        return false
    }

    private static func currentFocus() -> FocusSnapshot? {
        let system = AXUIElementCreateSystemWide()

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        let element = focused as! AXUIElement

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            return nil
        }

        let window = copyElement(element, kAXWindowAttribute as String)

        return FocusSnapshot(
            pid: pid,
            role: copyString(element, kAXRoleAttribute as String),
            subrole: copyString(element, kAXSubroleAttribute as String),
            windowSubrole: window.flatMap { copyString($0, kAXSubroleAttribute as String) },
            windowIsModal: window.flatMap { copyBool($0, modalAttribute) } ?? false
        )
    }

    private static func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func copyBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return (value as? NSNumber)?.boolValue
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }
}
