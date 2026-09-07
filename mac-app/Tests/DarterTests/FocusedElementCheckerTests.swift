import XCTest
@testable import Darter

/// Focus cases that decide whether a bound key is intercepted or handed back
/// to the system.
final class FocusedElementCheckerTests: XCTestCase {
    private let lightroomPID: pid_t = 100
    private let overlayPID: pid_t = 200

    private func focus(
        pid: pid_t? = nil,
        role: String? = nil,
        subrole: String? = nil,
        windowSubrole: String? = nil,
        windowIsModal: Bool = false
    ) -> FocusedElementChecker.FocusSnapshot {
        FocusedElementChecker.FocusSnapshot(
            pid: pid ?? lightroomPID,
            role: role,
            subrole: subrole,
            windowSubrole: windowSubrole,
            windowIsModal: windowIsModal
        )
    }

    private func passesThrough(_ snapshot: FocusedElementChecker.FocusSnapshot) -> Bool {
        FocusedElementChecker.shouldPassThrough(focus: snapshot, lightroomPID: lightroomPID)
    }

    // Typing a date into Metadata > Edit Capture Time fired slider shortcuts.
    // Lightroom leaves AX focus on the radio button rather than moving it to
    // the field being typed into, so only the window says what's going on.
    func testCaptureTimeDialogPassesThrough() {
        let captureTimeDialog = focus(
            role: kAXRadioButtonRole as String,
            windowSubrole: kAXDialogSubrole as String,
            windowIsModal: true
        )

        XCTAssertTrue(passesThrough(captureTimeDialog))
    }

    // A dialog that doesn't set the modal flag still owns the keyboard.
    func testDialogSubroleAlonePassesThrough() {
        XCTAssertTrue(passesThrough(focus(windowSubrole: kAXDialogSubrole as String)))
    }

    func testTextFieldPassesThrough() {
        XCTAssertTrue(passesThrough(focus(role: kAXTextFieldRole as String)))
    }

    func testSearchFieldSubrolePassesThrough() {
        let searchField = focus(
            role: kAXTextFieldRole as String,
            subrole: kAXSearchFieldSubrole as String
        )

        XCTAssertTrue(passesThrough(searchField))
    }

    // Raycast and friends float over Lightroom without taking frontmost.
    func testOverlayProcessPassesThrough() {
        XCTAssertTrue(passesThrough(focus(pid: overlayPID, role: kAXTextFieldRole as String)))
    }

    // The ordinary case: the photo view has focus, so the key is ours.
    func testPhotoViewIsIntercepted() {
        let photoView = focus(
            role: kAXGroupRole as String,
            windowSubrole: kAXStandardWindowSubrole as String
        )

        XCTAssertFalse(passesThrough(photoView))
    }
}
