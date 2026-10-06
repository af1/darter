import XCTest
@testable import Darter

/// Modifiers a downstream remapper holds never appear on the event we see,
/// so they have to be read from the live session state instead.
final class ModifierStateTests: XCTestCase {
    private func hidden(
        session: CGEventFlags,
        shift: Bool = false,
        option: Bool = false,
        command: Bool = false,
        control: Bool = false
    ) -> Bool {
        ModifierState.hidden(in: session, shift: shift, option: option, command: command, control: control)
    }

    // Caps Lock remapped to hyper: the B keyDown arrives with no flags at
    // all while the session reports the full chord.
    func testHyperChordIsHidden() {
        let hyper: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

        XCTAssertTrue(hidden(session: hyper))
    }

    func testSingleHiddenModifierCounts() {
        XCTAssertTrue(hidden(session: [.maskCommand]))
    }

    // A modifier the event already reported is accounted for, not hidden.
    func testReportedShiftIsNotHidden() {
        XCTAssertFalse(hidden(session: [.maskShift], shift: true))
    }

    func testReportedChordIsNotHidden() {
        let chord: CGEventFlags = [.maskControl, .maskShift]

        XCTAssertFalse(hidden(session: chord, shift: true, control: true))
    }

    func testPlainKeyIsNotHidden() {
        XCTAssertFalse(hidden(session: []))
    }

    // Caps Lock itself is not a chord modifier -- typing in caps must work.
    func testCapsLockAloneIsNotHidden() {
        XCTAssertFalse(hidden(session: [.maskAlphaShift]))
    }
}
