import Cocoa
import UniformTypeIdentifiers

/// Ties together config persistence, the global hotkey tap, the status bar
/// item, and the settings window.
final class Coordinator {
    private let configStore = ConfigStore()
    private let eventTap = EventTapManager()
    private let frontmostTracker = FrontmostAppTracker()
    private var statusItemController: StatusItemController?
    private var settingsWindowController: SettingsWindowController?

    /// Single source of truth for config. Every change funnels through here,
    /// and didSet fans it out to disk, the status item, and the settings
    /// window's view model -- so no consumer can hold a stale copy. (A
    /// settings view model that only snapshotted config at creation once
    /// caused a bound key to silently not work until app restart, and could
    /// commit its stale snapshot back over newer changes.)
    private(set) var config: AppConfig {
        didSet {
            guard config != oldValue else { return }
            configStore.save(config)
            statusItemController?.refresh()
            settingsWindowController?.syncConfig(config)
        }
    }

    var isMasterEnabled: Bool { config.masterEnabled }

    init() {
        config = configStore.load()
    }

    func start() {
        statusItemController = StatusItemController(coordinator: self)

        eventTap.onKeyDown = { [weak self] keyCode, shift, option, command, control, isAutorepeat in
            self?.handleKeyDown(keyCode: keyCode, shiftHeld: shift, optionHeld: option,
                                commandHeld: command, controlHeld: control, isAutorepeat: isAutorepeat) ?? false
        }
        eventTap.onKeyUp = { [weak self] keyCode in
            self?.stopArrowNavigation(keyCode: keyCode)
        }
        eventTap.start()
    }

    func stop() {
        eventTap.stop()
    }

    // MARK: Arrow-key photo navigation
    //
    // Plain left/right arrows are swallowed entirely while Lightroom is
    // frontmost and replaced with our own paced SDK next/previous-photo
    // commands. Reason: Lightroom's held-arrow scrolling runs on an internal
    // repeat that queues navigation faster than it can render, so after
    // releasing the key it kept scrolling for many seconds (14s observed).
    // Forward-throttling the OS autorepeats couldn't fix it -- the flood is
    // internal to Lightroom once it sees the key as held. By never letting
    // it see a held arrow, nothing can queue: at most one command is in
    // flight when the key is released, because we stop on keyUp.
    // Modified arrows (Shift-extend selection etc.) pass through untouched,
    // as do up/down.

    /// How long an arrow must stay held before continuous scrolling begins.
    private static let navHoldStartDelay: TimeInterval = 0.4
    private var navTimer: Timer?
    private var navHeldKeyCode: UInt16?

    // Native mode: how often we poll physical key state to notice the
    // release, and a hard ceiling so a missed release can never strand the
    // tap suspended.
    private static let navKeyStatePollInterval: TimeInterval = 0.025
    private static let navSuspendMaxDuration: TimeInterval = 10
    private var navSuspendTimer: Timer?

    /// Native mode: let the arrow through untouched and suspend our tap for
    /// the duration of the hold, so Lightroom sees exactly the event stream
    /// it would with Darter not running. Returns false always (we never
    /// swallow in this mode).
    ///
    /// Trade-off: while suspended we're blind, so other Darter shortcuts
    /// are inert until ~25ms after the arrow is released. Holding an arrow
    /// while reaching for Q/W isn't a real workflow, so this is acceptable.
    private func beginNativeArrowHold(keyCode: UInt16) -> Bool {
        guard !eventTap.isSuspended else { return false }
        eventTap.suspend()

        let deadline = ProcessInfo.processInfo.systemUptime + Self.navSuspendMaxDuration
        navSuspendTimer?.invalidate()
        // CGEventSource.keyState reads physical key state from the HID layer:
        // no event tap needed (we're suspended), and it doesn't touch
        // Lightroom's main thread the way an AX query would.
        navSuspendTimer = Timer.scheduledTimer(withTimeInterval: Self.navKeyStatePollInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let stillHeld = CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(keyCode))
            let lightroomStillFrontmost = self.frontmostTracker.bundleID == HotkeyMatcher.lightroomBundleID
            let timedOut = ProcessInfo.processInfo.systemUptime > deadline
            if !stillHeld || !lightroomStillFrontmost || timedOut {
                timer.invalidate()
                self.navSuspendTimer = nil
                self.eventTap.resume()
            }
        }
        return false
    }

    /// Hold-scroll pace from settings (photos per second -> seconds between
    /// commands), clamped defensively.
    private var navRepeatInterval: TimeInterval {
        1.0 / min(max(config.arrowNavPhotosPerSecond, 0.5), 50)
    }

    private func handleArrowNavigation(keyCode: UInt16, isAutorepeat: Bool, frontmostPID: pid_t?) -> Bool {
        if isAutorepeat {
            // Native mode never sees repeats (the tap is suspended for the
            // whole hold). Paced mode swallows repeats only for a hold we
            // own; if the initial press passed through (e.g. cursor movement
            // in a text field), its repeats must pass through too.
            return config.arrowNavMode == .paced && navHeldKeyCode == keyCode
        }

        // Typing context (search field, keyword box, Raycast overlay):
        // arrows move the cursor -- keep out entirely.
        if let pid = frontmostPID, FocusedElementChecker.shouldPassThrough(lightroomPID: pid) {
            return false
        }

        if config.arrowNavMode == .native {
            return beginNativeArrowHold(keyCode: keyCode)
        }

        let goNext = (keyCode == 124)
        navHeldKeyCode = keyCode
        LightroomURLSender.navigatePhoto(next: goNext)
        navTimer?.invalidate()
        // Like OS key repeat: one photo on the press, and continuous scroll
        // only starts after the key has been held a moment -- otherwise a
        // quick tap could slip in an extra fire or two before keyUp.
        navTimer = Timer.scheduledTimer(withTimeInterval: Self.navHoldStartDelay, repeats: false) { [weak self] _ in
            guard let self, self.navHeldKeyCode == keyCode else { return }
            self.navTimer = Timer.scheduledTimer(withTimeInterval: self.navRepeatInterval, repeats: true) { [weak self] timer in
                // Safety: if the release was missed (app switch mid-hold),
                // stop as soon as Lightroom is no longer frontmost.
                guard let self, self.frontmostTracker.bundleID == HotkeyMatcher.lightroomBundleID,
                      self.navHeldKeyCode == keyCode else {
                    timer.invalidate()
                    self?.navTimer = nil
                    self?.navHeldKeyCode = nil
                    return
                }
                LightroomURLSender.navigatePhoto(next: goNext)
            }
        }
        return true
    }

    func stopArrowNavigation(keyCode: UInt16) {
        guard keyCode == navHeldKeyCode else { return }
        navHeldKeyCode = nil
        navTimer?.invalidate()
        navTimer = nil
    }

    private func handleKeyDown(keyCode: UInt16, shiftHeld: Bool, optionHeld: Bool, commandHeld: Bool, controlHeld: Bool, isAutorepeat: Bool) -> Bool {
        // Cached, not NSWorkspace.frontmostApplication: this runs on EVERY
        // keystroke inside the synchronous tap, and the workspace call was
        // slow enough that held key-repeat (e.g. arrow-key photo navigation)
        // backed up and kept firing after release.
        let frontmostPID = frontmostTracker.processID
        let frontmostIsLightroom = frontmostTracker.bundleID == HotkeyMatcher.lightroomBundleID

        // Plain left/right arrows: take over navigation (see MARK above).
        // Gated on masterEnabled so Shift+Esc returns arrows to Lightroom's
        // native handling along with everything else.
        if frontmostIsLightroom, config.masterEnabled, keyCode == 123 || keyCode == 124,
           !shiftHeld, !optionHeld, !commandHeld, !controlHeld {
            return handleArrowNavigation(keyCode: keyCode, isAutorepeat: isAutorepeat, frontmostPID: frontmostPID)
        }

        guard let action = HotkeyMatcher.match(
            config: config,
            keyCode: keyCode,
            shiftHeld: shiftHeld,
            optionHeld: optionHeld,
            commandHeld: commandHeld,
            controlHeld: controlHeld,
            frontmostBundleID: frontmostTracker.bundleID
        ) else {
            return false
        }

        // Only checked once we're already about to intercept a key -- an
        // Accessibility query per keystroke would slow down ordinary typing,
        // but for the small set of bound keys it's worth the round trip.
        // Catches both a text field inside Lightroom (keyword box, filter
        // bar, Help search) and an overlay launcher floating over it
        // (Raycast/Spotlight), which NSWorkspace still reports as Lightroom
        // being frontmost.
        if let pid = frontmostPID,
           FocusedElementChecker.shouldPassThrough(lightroomPID: pid) {
            return false
        }

        switch action {
        case .adjustSlider(let paramName, let delta, let relativeDelta):
            LightroomURLSender.send(paramName: paramName, delta: delta, relativeDelta: relativeDelta)
        case .activateTool(let toolName) where toolName == "AutoStraighten":
            activateAutoStraighten(pid: frontmostPID)
        case .activateTool(let toolName) where toolName == "RotateCropAspect":
            rotateCropAspect(pid: frontmostPID)
        case .activateTool(let toolName) where toolName == "WhiteBalancePicker":
            // No SDK hook; synthesize Lightroom's native W. Safe from any
            // module -- W natively jumps to Develop and arms the eyedropper.
            synthesizeNativeKey(KeyCode.w, pid: frontmostPID)
        case .activateTool(let toolName) where toolName == "InfoOverlay":
            // No SDK hook; synthesize Lightroom's native I (cycles the
            // loupe info overlay).
            synthesizeNativeKey(KeyCode.i, pid: frontmostPID)
        case .activateTool(let toolName):
            LightroomURLSender.sendTool(toolName: toolName)
        case .applyPreset(let folder, let name):
            LightroomURLSender.applyPreset(folder: folder, name: name)
        case .toggleMasterEnabled:
            config.masterEnabled.toggle()
        }
        return true
    }

    /// Goes through the plugin (SDK) to open the Crop tool -- reliable and
    /// consistent with everything else -- then, once the crop panel has had
    /// a moment to render, presses the real "Auto" button via Accessibility.
    /// See LightroomUIAutomation for why this one action can't go through
    /// the plugin at all.
    private func activateAutoStraighten(pid: pid_t?) {
        LightroomURLSender.sendTool(toolName: "Crop")
        guard let pid else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            _ = LightroomUIAutomation.pressAutoStraightenButton(pid: pid)
        }
    }

    /// "Rotate crop aspect" has neither an SDK hook nor an AX button -- it
    /// only exists as Lightroom's native X shortcut while the crop overlay
    /// is open. So: confirm the crop tool is actually active (outside it, X
    /// means "reject photo" -- never send it blind), then synthesize X.
    private func rotateCropAspect(pid: pid_t?) {
        guard let pid else { return }
        DispatchQueue.main.async {
            if LightroomUIAutomation.isCropToolActive(pid: pid) {
                EventTapManager.expectSyntheticKey(KeyCode.x)
                KeySynthesizer.postKey(CGKeyCode(KeyCode.x), toPid: pid)
            }
        }
    }

    /// For actions with no SDK hook but a native Lightroom shortcut: post
    /// that key to Lightroom, after telling the tap the next occurrence is
    /// ours (the key may itself be bound in our config -- e.g. the
    /// synthesized W for the white-balance picker is Temperature-increase
    /// here).
    private func synthesizeNativeKey(_ keyCode: UInt16, pid: pid_t?) {
        guard let pid else { return }
        DispatchQueue.main.async {
            EventTapManager.expectSyntheticKey(keyCode)
            KeySynthesizer.postKey(CGKeyCode(keyCode), toPid: pid)
        }
    }

    func updateConfig(_ newConfig: AppConfig) {
        config = newConfig
    }

    func toggleMasterEnabledFromMenu() {
        config.masterEnabled.toggle()
    }

    func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(coordinator: self)
        }
        // Re-sync in case anything changed since the window was last shown
        // (the controller and its view model are cached for the app's life).
        settingsWindowController?.syncConfig(config)
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Darter Settings.json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(config).write(to: url)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let imported = try JSONDecoder().decode(AppConfig.self, from: data)
            // Same normalization as the startup load, so a file exported
            // from an older version picks up migrations and new defaults.
            updateConfig(ConfigStore.normalized(imported))
        } catch {
            showAlert(title: "Import Failed",
                      message: "That file doesn't look like Darter settings.\n\n\(error.localizedDescription)")
        }
    }

    func loadStarterProfile(_ profile: StarterProfile) {
        let alert = NSAlert()
        alert.messageText = "Load the “\(profile.name)” layout?"
        alert.informativeText = "This replaces your slider and tool key bindings, step sizes, and modifiers. Your preset shortcuts (⌘1–0) are kept."
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // A layout profile shouldn't wipe personal choices that aren't about
        // the layout -- keep the user's Lightroom preset assignments and
        // their on/off state.
        var newConfig = profile.config
        newConfig.presetSlots = config.presetSlots
        newConfig.masterEnabled = config.masterEnabled
        updateConfig(ConfigStore.normalized(newConfig))
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
