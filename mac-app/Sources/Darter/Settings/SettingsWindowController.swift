import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private var viewModel: SettingsViewModel?
    private var hosting: NSHostingController<SettingsRootView>?

    private static let contentWidth: CGFloat = 600

    convenience init(coordinator: Coordinator) {
        let viewModel = SettingsViewModel(coordinator: coordinator)
        let hosting = NSHostingController(rootView: SettingsRootView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hosting)
        // Version read straight from the bundle so the title always matches
        // the actual build -- nothing separate to keep in sync.
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        window.title = "Darter Settings — v\(version)"
        // Not resizable by the user: the window is sized exactly to its
        // content (per tab), so resizing would only reveal dead space.
        window.styleMask = [.titled, .closable, .miniaturizable]
        // We keep our own strong reference to this window controller for the
        // whole app lifetime and reuse it across opens/closes -- don't let
        // AppKit's default (release-on-close) tear it down out from under us.
        window.isReleasedWhenClosed = false

        window.setContentSize(NSSize(width: Self.contentWidth, height: 640))
        self.init(window: window)
        self.viewModel = viewModel
        self.hosting = hosting
        // Re-target the root view at a closure that can reach self (not
        // possible before self.init).
        hosting.rootView = SettingsRootView(viewModel: viewModel) { [weak self] in
            self?.sizeWindowToContent()
        }
        sizeWindowToContent()
        window.center()
    }

    /// Sizes the window so the currently visible tab's Form never scrolls.
    /// A grouped Form is a scroll view, so its fittingSize lies about the
    /// content height -- instead, lay out at the current height, measure how
    /// much the scroll view's document over- or under-shoots its viewport,
    /// and adjust the window by exactly that (capped to the screen). Called
    /// at creation and on every tab switch, since each tab differs in
    /// natural height.
    private func sizeWindowToContent() {
        guard let window, let hosting else { return }
        // Defer a runloop turn so SwiftUI has laid out the newly shown tab.
        DispatchQueue.main.async {
            hosting.view.layoutSubtreeIfNeeded()
            guard let scrollView = Self.findScrollView(in: hosting.view),
                  let document = scrollView.documentView else { return }
            let overflow = document.frame.height - scrollView.contentSize.height
            guard abs(overflow) > 1 else { return }
            let current = window.contentLayoutRect.height
            let maxHeight = (NSScreen.main?.visibleFrame.height ?? 1000) - 40
            let target = min(max(current + overflow + 2, 420), maxHeight)
            window.setContentSize(NSSize(width: Self.contentWidth, height: target))
        }
    }

    private static func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) { return found }
        }
        return nil
    }

    /// Called by the Coordinator whenever config changes anywhere (hotkey
    /// toggle, menu toggle, load) so the settings UI never shows -- or worse,
    /// commits back -- a stale snapshot.
    func syncConfig(_ config: AppConfig) {
        guard let viewModel, viewModel.config != config else { return }
        viewModel.config = config
    }
}
