import AppKit
import KeyboardShortcuts
import SwiftUI

/// Sets up the menu bar status item, the centered Spotlight panel, and the
/// global hotkey. Replaces the old `MenuBarExtra` scene so the panel can be
/// opened programmatically (which `MenuBarExtra` does not allow).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Shared app state, also handed to the Settings scene.
    let state = AppState()

    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelController = PanelController(state: state)
        panelController.onOpenSettings = { [weak self] in self?.showSettings() }
        self.panelController = panelController

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = MenuBarIcon.image
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.statusItem = statusItem

        // The global hotkey opens the centered "Spotlight" window (power users);
        // clicking the menu-bar icon keeps the classic anchored dropdown.
        KeyboardShortcuts.onKeyUp(for: .toggleShuttleX) { [weak panelController] in
            panelController?.toggle(anchor: .center)
        }
    }

    /// Left-click toggles the anchored dropdown; right-click shows a small menu.
    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            panelController.toggle(anchor: .statusItem(statusItemRect()))
        }
    }

    /// The menu-bar button's frame in screen coordinates, used to anchor the
    /// dropdown beneath it.
    private func statusItemRect() -> NSRect {
        guard let button = statusItem.button, let window = button.window else { return .zero }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open ShuttleX", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit ShuttleX", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        // Attach the menu just for this click, then detach so left-click keeps
        // toggling the panel instead of opening the menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanel() { panelController.show(anchor: .statusItem(statusItemRect())) }
    @objc func openSettings() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    /// Shows the Settings window, creating it on first use. We own it as a plain
    /// AppKit window instead of relying on SwiftUI's `Settings` scene + the
    /// private `showSettingsWindow:` selector, which is unreliable for an
    /// accessory app (and varies across macOS versions).
    private func showSettings() {
        // Close the transient (floating) panel first, so Settings comes cleanly
        // to the front regardless of entry point (gear, ⌘,, right-click).
        panelController?.hide()
        if settingsWindow == nil {
            let hosting = NSHostingView(rootView: SettingsView().environment(state))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "ShuttleX Settings"
            window.contentView = hosting
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Hide the panel when the user switches to another app (e.g. via ⌘-Tab).
    /// Picker menus inside the panel don't deactivate the app, so they're safe.
    func applicationDidResignActive(_ notification: Notification) {
        panelController?.hide()
    }
}
