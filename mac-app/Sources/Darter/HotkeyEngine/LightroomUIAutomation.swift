import ApplicationServices
import Foundation

/// The one shortcut that can't go through the Lightroom plugin SDK: the
/// crop tool's "Auto" straighten button runs an internal image-analysis
/// algorithm with no scripting hook (LrDevelopController only exposes
/// getting/setting straightenAngle, not computing it). Confirmed via a
/// before/after diff of every candidate develop parameter around a manual
/// click -- only straightenAngle changed, and there's no API to ask
/// Lightroom to compute that value itself.
///
/// So this presses the real button directly via the Accessibility API,
/// identified by its exact title + help text (confirmed by walking
/// Lightroom's live accessibility tree): AXButton "Auto", help
/// "Automatically straighten the photo." No mouse movement -- AXPress
/// invokes the button's action programmatically.
enum LightroomUIAutomation {
    static func pressAutoStraightenButton(pid: pid_t) -> Bool {
        guard let button = locateAutoStraightenButton(pid: pid) else { return false }
        AXUIElementPerformAction(button, kAXPressAction as CFString)
        return true
    }

    /// The crop panel's Auto button only exists in the accessibility tree
    /// while the Crop tool is open -- which makes it a reliable "is the crop
    /// overlay active?" probe. Used to guard actions that are only safe in
    /// crop mode (e.g. synthesizing X for rotate-crop-aspect: outside the
    /// crop overlay, X means "reject photo" in Lightroom).
    static func isCropToolActive(pid: pid_t) -> Bool {
        locateAutoStraightenButton(pid: pid) != nil
    }

    private static func locateAutoStraightenButton(pid: pid_t) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(pid)
        guard let windows = attribute(axApp, kAXWindowsAttribute) as? [AXUIElement] else {
            return nil
        }
        for window in windows {
            if let button = findAutoStraightenButton(in: window, depth: 0) {
                return button
            }
        }
        return nil
    }

    private static func findAutoStraightenButton(in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 30 else { return nil }

        if let role = attribute(element, kAXRoleAttribute) as? String, role == "AXButton",
           let title = attribute(element, kAXTitleAttribute) as? String, title == "Auto",
           let help = attribute(element, kAXHelpAttribute) as? String,
           help.localizedCaseInsensitiveContains("straighten") {
            return element
        }

        guard let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] else {
            return nil
        }
        for child in children {
            if let found = findAutoStraightenButton(in: child, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}
