import Cocoa

/// Wraps a global CGEventTap for key-down events. A raw event tap (rather
/// than Carbon's RegisterEventHotKey) is used because it's the only way to
/// read live modifier-key state (Option/Shift) alongside the key code in a
/// single callback -- needed for the "hold Option/Shift to scale the
/// adjustment amount" behavior.
final class EventTapManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
    private var permissionRetryTimer: Timer?

    /// True while the tap is deliberately disabled (see suspend()). Distinct
    /// from the tap being disabled *by the system*, which we do want to
    /// recover from -- so both auto-recovery paths below must honour this.
    private(set) var isSuspended = false

    /// Return true to swallow the event (don't pass it through to the
    /// frontmost app); false to let it propagate normally.
    var onKeyDown: ((_ keyCode: UInt16, _ shiftHeld: Bool, _ optionHeld: Bool, _ commandHeld: Bool, _ controlHeld: Bool, _ isAutorepeat: Bool) -> Bool)?

    /// Observation only -- keyUps always pass through. Used to stop the
    /// arrow-key navigation timer the moment the key is released.
    var onKeyUp: ((_ keyCode: UInt16) -> Void)?

    // CGEventTapCallBack must be a context-free C function pointer, so it
    // can't capture `self`. A single-instance static reference stands in for
    // that; this app only ever creates one EventTapManager.
    private static weak var activeInstance: EventTapManager?

    // Self-event suppression for synthesized keystrokes. The
    // eventSourceUserData marker turned out not to survive the trip through
    // the event system reliably, so the sender declares the key it's about
    // to post and the tap passes the next occurrence through untouched.
    // Both sides run on the main thread (the tap's run loop), so there's no
    // race.
    private static var suppressKeyCode: UInt16?
    private static var suppressUntil: TimeInterval = 0

    /// Call immediately before KeySynthesizer.postKey: the next keyDown of
    /// this key within half a second is ours and must not be intercepted.
    static func expectSyntheticKey(_ keyCode: UInt16) {
        suppressKeyCode = keyCode
        suppressUntil = ProcessInfo.processInfo.systemUptime + 0.5
    }

    func start() {
        guard eventTap == nil else { return }

        guard AccessibilityPermission.isGranted() else {
            AccessibilityPermission.request()
            schedulePermissionRetry()
            return
        }

        createTap()
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        if EventTapManager.activeInstance === self {
            EventTapManager.activeInstance = nil
        }
    }

    /// Temporarily take the tap out of the event-delivery path entirely.
    ///
    /// An active tap re-posts every key event, which defeats the WindowServer
    /// coalescing that normally throttles key-repeat into a busy app -- the
    /// cause of Lightroom's runaway arrow-key overscroll. Suspending restores
    /// fully native delivery (identical to Darter not running) for the
    /// duration of a held arrow. While suspended we are blind to all keys,
    /// so callers must arrange their own resume (see Coordinator's keyState
    /// polling).
    func suspend() {
        guard let tap = eventTap, !isSuspended else { return }
        isSuspended = true
        CGEvent.tapEnable(tap: tap, enable: false)
    }

    func resume() {
        guard let tap = eventTap, isSuspended else { return }
        isSuspended = false
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Permission can be granted by the user *after* the app has already
    /// launched (they switch to System Settings mid-session); poll briefly
    /// so the tap comes alive without requiring a relaunch.
    private func schedulePermissionRetry() {
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, self.eventTap == nil else { return }
            if AccessibilityPermission.isGranted() {
                self.permissionRetryTimer?.invalidate()
                self.permissionRetryTimer = nil
                self.createTap()
            }
        }
    }

    private func createTap() {
        // keyUp is observation-only (always passed through); it exists so
        // held-arrow navigation can stop the instant the key is released.
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
        EventTapManager.activeInstance = self

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, _ in
                EventTapManager.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        healthCheckTimer?.invalidate()
        // Belt-and-suspenders: macOS can disable a tap after a timeout or
        // under load. The callback re-enables it inline when it sees that
        // happen, but this periodic check catches anything it misses.
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
    }

    private func checkHealth() {
        // Don't fight a deliberate suspend -- without this guard the 5s timer
        // would re-enable the tap mid-hold and reintroduce the overscroll.
        guard let tap = eventTap, !isSuspended else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private static func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let instance = activeInstance else {
            return Unmanaged.passRetained(event)
        }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Same guard as checkHealth(): a deliberate suspend must not be
            // undone here. (tapDisabledByUserInput can fire as a result of
            // our own tapEnable(false) call.)
            if let tap = instance.eventTap, !instance.isSuspended {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        if type == .keyUp {
            instance.onKeyUp?(UInt16(event.getIntegerValueField(.keyboardEventKeycode)))
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        // Never intercept our own synthesized keystrokes (KeySynthesizer) --
        // otherwise the X we send for "rotate crop aspect" would match the
        // user's X binding and fire a slider adjustment. (In practice
        // pid-targeted posts bypass this session tap entirely, but keep the
        // guard in case delivery behavior differs across macOS versions.)
        if keyCode == suppressKeyCode, ProcessInfo.processInfo.systemUptime < suppressUntil {
            suppressKeyCode = nil
            return Unmanaged.passRetained(event)
        }
        let flags = event.flags
        let shiftHeld = flags.contains(.maskShift)
        let optionHeld = flags.contains(.maskAlternate)
        let commandHeld = flags.contains(.maskCommand)
        let controlHeld = flags.contains(.maskControl)

        if let onKeyDown = instance.onKeyDown,
           onKeyDown(keyCode, shiftHeld, optionHeld, commandHeld, controlHeld, isAutorepeat) {
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
