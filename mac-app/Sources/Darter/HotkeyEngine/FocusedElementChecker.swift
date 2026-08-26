import ApplicationServices
import Foundation

/// Decides whether a matched key should be let through to the system instead
/// of intercepted -- because keyboard focus isn't really in Lightroom's photo
/// view. Two cases:
///   1. An overlay launcher (Raycast, Spotlight, Alfred) is floating over
///      Lightroom. These use non-activating panels, so
///      NSWorkspace.frontmostApplication still reports Lightroom -- but the
///      keystroke belongs to the overlay's search field.
///   2. A text field inside Lightroom itself is focused (keyword box, filter
///      bar, rename, the Help menu search).
///
/// Both are answered by one query against the SYSTEM-WIDE focused UI element
/// (who owns keyboard focus right now), so this stays a single AX call --
/// and it's only made after HotkeyMatcher already matched a bound key, never
/// on ordinary typing, so there's no per-keystroke cost.
enum FocusedElementChecker {
    private static let textInputRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        kAXSearchFieldSubrole as String,
    ]

    static func shouldPassThrough(lightroomPID: pid_t) -> Bool {
        let system = AXUIElementCreateSystemWide()

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            // Nothing reports keyboard focus. NSWorkspace already says
            // Lightroom is frontmost, so treat it as ours and intercept.
            return false
        }
        let element = focused as! AXUIElement

        // Focus is in a different process (an overlay floating over
        // Lightroom) -- the keystroke is theirs.
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success, pid != lightroomPID {
            return true
        }

        // Same process, but a text input (keyword box, filter, search) --
        // let the user type.
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let roleString = role as? String, textInputRoles.contains(roleString) {
            return true
        }
        // Some search fields report role=AXTextField but distinguish via
        // subrole; also check that.
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           let subroleString = subrole as? String, textInputRoles.contains(subroleString) {
            return true
        }

        return false
    }
}
