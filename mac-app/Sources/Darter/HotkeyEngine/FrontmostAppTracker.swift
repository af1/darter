import AppKit

/// Caches which app is frontmost, updated only when the active app changes.
///
/// The event tap is synchronous -- every keystroke waits for our callback to
/// return before it proceeds. Calling NSWorkspace.frontmostApplication in
/// that callback (as we used to, on every key) crosses into the workspace
/// service each time; under fast key-repeat (holding an arrow) the events
/// queue faster than they drain and keep firing after release. Reading a
/// cached value instead makes the per-keystroke path near-instant.
///
/// Everything here runs on the main thread: the tap's run-loop source lives
/// on the main run loop, and the notification is delivered on the main
/// queue, so no locking is needed.
///
/// Note: overlay launchers (Raycast/Spotlight) use non-activating panels and
/// do NOT post an activation notification, so this keeps reporting Lightroom
/// as frontmost while they're up -- which is correct. The Raycast case is
/// handled separately by FocusedElementChecker after a key matches.
final class FrontmostAppTracker {
    private(set) var bundleID: String?
    private(set) var processID: pid_t?
    private var observer: NSObjectProtocol?

    init() {
        update(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.update(app ?? NSWorkspace.shared.frontmostApplication)
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func update(_ app: NSRunningApplication?) {
        bundleID = app?.bundleIdentifier
        processID = app?.processIdentifier
    }
}
