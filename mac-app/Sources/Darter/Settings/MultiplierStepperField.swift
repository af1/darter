import AppKit
import SwiftUI

/// NumberFormatter that REJECTS invalid keystrokes as they're typed --
/// isPartialStringValid runs on every edit of the field editor, and
/// returning false refuses the change outright (with the system beep),
/// rather than letting bad input land and sanitizing it afterwards. Only
/// digits and at most one decimal point ever make it into the field.
final class DecimalInputFormatter: NumberFormatter, @unchecked Sendable {
    override func isPartialStringValid(
        _ partialString: String,
        newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        partialString.isEmpty ||
            partialString.range(of: #"^\d*\.?\d*$"#, options: .regularExpression) != nil
    }
}

/// Numeric field + up/down stepper for the Option/Shift multipliers. Rejects
/// non-numeric typing outright and clamps to `range` in steps of 0.1.
struct MultiplierStepperField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private static let step = 0.1

    // Per-instance (not static) because the two multiplier fields clamp to
    // different ranges, so the formatter's min/max differ.
    private let formatter: DecimalInputFormatter

    init(value: Binding<Double>, range: ClosedRange<Double>) {
        self._value = value
        self.range = range
        let f = DecimalInputFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 2
        f.minimum = NSNumber(value: range.lowerBound)
        f.maximum = NSNumber(value: range.upperBound)
        self.formatter = f
    }

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, formatter: formatter)
                .frame(width: 50)
                .multilineTextAlignment(.trailing)
                // Commit clamps too: the formatter's min/max bounds what a
                // typed value resolves to, but round-trip through our own
                // clamp so out-of-range entries snap into the band.
                .onChange(of: value) { _ in clamp() }
            Stepper("", onIncrement: { adjust(by: Self.step) },
                        onDecrement: { adjust(by: -Self.step) })
                .labelsHidden()
        }
    }

    /// Step in exact tenths -- rounding after each step keeps repeated
    /// increments from accumulating binary floating-point noise
    /// (0.30000000000000004-style values).
    private func adjust(by delta: Double) {
        let stepped = ((value + delta) * 10).rounded() / 10
        value = min(max(stepped, range.lowerBound), range.upperBound)
    }

    private func clamp() {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        if clamped != value { value = clamped }
    }
}
