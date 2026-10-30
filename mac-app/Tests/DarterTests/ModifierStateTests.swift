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

    // Deliberately the opposite of what this asserted when the check was
    // introduced. A lone hidden modifier turned out to be a race rather than
    // a chord, which cost real keypresses -- see the two tests below.
    func testSingleHiddenModifierIsTreatedAsRace() {
        XCTAssertFalse(hidden(session: [.maskCommand]))
    }

    // Measured flags, captured when Shift+E passed through to Lightroom and
    // switched it to the Library module. Shift is held but the E event was
    // built before it registered. The low bits are the right-shift device
    // bit and the non-coalesced bit, neither of which should matter here.
    func testRacingShiftIsNotHidden() {
        XCTAssertFalse(hidden(session: CGEventFlags(rawValue: 0x20104)))
    }

    // Measured flags from the hyper key: all four modifiers at once.
    func testMeasuredHyperChordIsHidden() {
        XCTAssertTrue(hidden(session: CGEventFlags(rawValue: 0x1e012b)))
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
