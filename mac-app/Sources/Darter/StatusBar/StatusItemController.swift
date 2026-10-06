import Cocoa

final class StatusItemController {
    private let statusItem: NSStatusItem
    private weak var coordinator: Coordinator?
    private let enabledMenuItem = NSMenuItem()

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Darter")

        let menu = NSMenu()

        enabledMenuItem.title = "Enabled"
        enabledMenuItem.action = #selector(toggleEnabled)
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // No action, so AppKit greys it out for us -- it's a label, not a
        // command.
        menu.addItem(NSMenuItem(title: "Darter \(AppInfo.version)", action: nil, keyEquivalent: ""))

        let updatesItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Darter", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refresh()
    }

    func refresh() {
        enabledMenuItem.state = (coordinator?.isMasterEnabled ?? true) ? .on : .off
    }

    @objc private func toggleEnabled() {
        coordinator?.toggleMasterEnabledFromMenu()
    }

    @objc private func openSettings() {
        coordinator?.openSettings()
    }

    @objc private func checkForUpdates() {
        NSWorkspace.shared.open(AppInfo.releasesURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
