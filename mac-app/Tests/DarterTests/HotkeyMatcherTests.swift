import XCTest
@testable import Darter

/// Modifier handling around bound plain keys. The cases that matter are the
/// ones where a held modifier means "somebody else's shortcut" rather than
/// "scale this adjustment".
final class HotkeyMatcherTests: XCTestCase {
    private let saturationStep: Double = 10

    /// Mirrors a real setup: Control chosen as the small-step modifier to
    /// free up Option for other apps.
    private var config: AppConfig = {
        var config = AppConfig.default
        config.smallMultiplierModifier = .control
        config.largeMultiplierModifier = .shift
        return config
    }()

    private func match(
        _ keyCode: UInt16,
        shift: Bool = false,
        option: Bool = false,
        command: Bool = false,
        control: Bool = false
    ) -> HotkeyAction? {
        HotkeyMatcher.match(
            config: config,
            keyCode: keyCode,
            shiftHeld: shift,
            optionHeld: option,
            commandHeld: command,
            controlHeld: control,
            frontmostBundleID: HotkeyMatcher.lightroomBundleID
        )
    }

    private func saturation(_ multiplier: Double) -> HotkeyAction {
        .adjustSlider(paramName: "Saturation", delta: -saturationStep * multiplier, relativeDelta: nil)
    }

    // A hyper key held two designated modifiers at once (Control+Shift here),
    // which matched B and moved Saturation instead of reaching the app that
    // owns the hyper chord.
    func testHyperChordDoesNotMatch() {
        XCTAssertNil(match(KeyCode.b, shift: true, control: true))
    }

    func testMehChordDoesNotMatch() {
        XCTAssertNil(match(KeyCode.b, shift: true, option: true, control: true))
    }

    func testFullHyperChordDoesNotMatch() {
        XCTAssertNil(match(KeyCode.b, shift: true, option: true, command: true, control: true))
    }

    // One multiplier modifier on its own is the feature working as intended.
    func testControlScalesStepDown() {
        XCTAssertEqual(match(KeyCode.b, control: true), saturation(config.smallMultiplier))
    }

    func testShiftScalesStepUp() {
        XCTAssertEqual(match(KeyCode.b, shift: true), saturation(config.largeMultiplier))
    }

    func testPlainKeyUsesFullStep() {
        XCTAssertEqual(match(KeyCode.b), saturation(1))
    }

    // Shift belongs to this binding's identity, so the only modifier acting
    // as a multiplier is Control -- still a single one, still a match.
    func testShiftBindingTakesControlMultiplier() {
        let rotate = match(KeyCode.tab, shift: true, control: true)

        XCTAssertEqual(rotate, .activateTool(toolName: "RotateCropAspect"))
    }

    // An undesignated modifier still blocks, as before.
    func testUndesignatedOptionDoesNotMatch() {
        XCTAssertNil(match(KeyCode.b, option: true))
    }
}
