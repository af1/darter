import AppKit
import SwiftUI

/// Click to arm, then press any key to record it as the binding -- uses a
/// *local* event monitor scoped to this window only, so it needs no
/// Accessibility permission (unlike the app's global CGEventTap).
struct KeyCaptureField: View {
    @Binding var binding: KeyBinding?
    /// Changes to a fresh UUID when this slot's key was just stolen by an
    /// assignment elsewhere -- triggers a red outline that fades, so the
    /// user sees where the key went missing from.
    var stealPulse: UUID? = nil
    @State private var isCapturing = false
    @State private var isHovering = false
    @State private var monitor: Any?
    @State private var stolenFlashOpacity: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            Button(action: startCapture) {
                Text(isCapturing ? "Press a key…" : (binding.map(Self.label(for:)) ?? "Type"))
                    .frame(minWidth: 60)
            }
            .buttonStyle(.bordered)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.red, lineWidth: 2)
                    .opacity(stolenFlashOpacity)
            )
            .onChange(of: stealPulse) { newValue in
                guard newValue != nil else { return }
                stolenFlashOpacity = 1
                withAnimation(.easeOut(duration: 1.5)) {
                    stolenFlashOpacity = 0
                }
            }

            // Always in the layout (so rows don't shift), but only visible
            // while hovering a bound key -- hidden it still keeps its slot.
            Button(action: clear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(binding != nil && isHovering ? 1 : 0)
            .allowsHitTesting(binding != nil && isHovering)
        }
        .onHover { isHovering = $0 }
        // If the settings window closes (or this row otherwise leaves the
        // hierarchy) while a capture is in progress, the local NSEvent
        // monitor from startCapture() would never get removed -- it isn't
        // tied to the button's lifetime, only to an explicit removeMonitor
        // call. Both of these make sure that always happens.
        .onDisappear { stopCapture() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            stopCapture()
        }
    }

    private func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Command/Control chords aren't bindable (Cmd+digit is reserved
            // for presets, and Command isn't part of the binding model) --
            // let them through untouched so e.g. Cmd+C still copies while
            // capture is armed, and keep listening.
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                return event
            }
            binding = KeyBinding(
                keyCode: event.keyCode,
                requiresShift: event.modifierFlags.contains(.shift),
                requiresOption: event.modifierFlags.contains(.option)
            )
            stopCapture()
            return nil
        }
    }

    private func stopCapture() {
        isCapturing = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func clear() {
        binding = nil
    }

    /// "⇧Tab", "⌥⇧E", or just "Q" -- required modifiers are part of the
    /// binding's identity, so the label must show them.
    private static func label(for binding: KeyBinding) -> String {
        var label = ""
        if binding.requiresOption { label += "⌥" }
        if binding.requiresShift { label += "⇧" }
        return label + KeyCode.displayName(for: binding.keyCode)
    }
}
