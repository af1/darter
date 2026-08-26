import ApplicationServices

/// This app needs exactly one TCC permission: Accessibility.
///
/// - The global hotkey tap is an *active* CGEventTap (.defaultTap -- it
///   swallows matched keys), which macOS gates on Accessibility. Input
///   Monitoring (kTCCServiceListenEvent) is only required for *listen-only*
///   keyboard taps, which we don't use.
/// - The AX queries (FocusedElementChecker, LightroomUIAutomation) are also
///   gated on Accessibility.
///
/// So check AXIsProcessTrusted, NOT CGPreflightListenEventAccess -- the
/// latter checks Input Monitoring, a different TCC bucket, and previously
/// gave a false "granted" here while tapCreate still failed because the
/// actual Accessibility grant had gone stale.
enum AccessibilityPermission {
    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Returns current trust state; if not trusted, asks macOS to show the
    /// "wants to control this computer using accessibility features" prompt.
    @discardableResult
    static func request() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
