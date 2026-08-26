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

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
