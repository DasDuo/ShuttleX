import AppKit
import KeyboardShortcuts
import SwiftUI

/// Sets up the menu bar status item, the centered Spotlight panel, and the
/// global hotkey. Replaces the old `MenuBarExtra` scene so the panel can be
/// opened programmatically (which `MenuBarExtra` does not allow).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// Shared app state, also handed to the Settings scene.
    let state = AppState()

    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var settingsWindow: NSWindow?
    /// The server editor lives in its own window — it manages your server list
    /// rather than configuring the app, so it isn't a sheet on Settings.
    private var editorWindow: NSWindow?
    /// True when the editor was opened from the menu, so closing it brings the
    /// menu back instead of leaving the user with nothing.
    private var editorOpenedFromMenu = false
    /// Same for Settings: opened from the menu's gear, closing it returns to the
    /// menu. Opened via ⌘, or the right-click menu, it doesn't — the user had no
    /// menu on screen, so popping one up would be a surprise.
    private var settingsOpenedFromMenu = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelController = PanelController(state: state)
        panelController.onOpenSettings = { [weak self] in self?.showSettings() }
        panelController.hasVisibleAuxWindow = { [weak self] in
            guard let self else { return false }
            return (settingsWindow?.isVisible ?? false) || (editorWindow?.isVisible ?? false)
        }
        panelController.onOpenEditor = { [weak self] in self?.showEditor() }
        state.openEditor = { [weak self] in self?.showEditor() }
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

        // Nothing of ours is on screen yet, so a restored placeholder window
        // from the empty Settings scene can be cleared right away.
        DispatchQueue.main.async { [weak self] in self?.closePlaceholderWindows() }
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
    /// The app needs one SwiftUI scene, so `ShuttleXApp` carries an empty
    /// `Settings` scene as a placeholder. macOS can restore that scene as a
    /// blank window — and since activating the app brings *every* window of
    /// ours forward, it then shows up next to the real settings window. Close
    /// any such stray window; the one we manage is excluded by identity.
    private func closePlaceholderWindows() {
        for window in NSApp.windows
        where window !== settingsWindow && window !== editorWindow
            && window.title.contains("Settings") {
            panelLog.notice("closing placeholder window (title=\(window.title, privacy: .public))")
            window.close()
        }
    }

    private func showSettings() {
        closePlaceholderWindows()
        // Decide before hiding the panel: if the menu was up, that's where the
        // user came from — whether they clicked the gear or pressed ⌘,.
        if panelController.isVisible { settingsOpenedFromMenu = true }
        // Close the transient (floating) panel first, so Settings comes cleanly
        // to the front regardless of entry point (gear, ⌘,, right-click) —
        // without handing focus away, since our own Settings window is next.
        panelController?.hide(returnFocus: false, reason: "open settings")
        if settingsWindow == nil {
            let hosting = NSHostingView(rootView: SettingsView().environment(state))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "ShuttleX Settings"
            // We create and own this window; letting macOS restore a copy of it
            // is what produces stray blank windows.
            window.isRestorable = false
            // Resizable on purpose: hiding the zoom button leaves a gap where
            // it should be, and a disabled one looks broken — so make it do
            // something instead. Long server lists get more room, too. The
            // minimum keeps the window wider than the sheets it hosts.
            window.minSize = NSSize(width: 520, height: 420)
            window.contentView = hosting
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Shows the server editor for the active source in its own window.
    /// `~/.ssh/config` has no editor — the menu hides the button there.
    private func showEditor() {
        guard state.source != .sshConfig else { return }
        if panelController.isVisible { editorOpenedFromMenu = true }
        panelController?.hide(returnFocus: false, reason: "open editor")

        if editorWindow == nil {
            let close: () -> Void = { [weak self] in self?.editorWindow?.close() }
            let content: AnyView = state.source == .remoteJSON
                ? AnyView(RemoteEditorView(state: state, onClose: close))
                : AnyView(ServerEditorView(state: state, onClose: close))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "ShuttleX — Servers"
            window.isRestorable = false
            window.contentView = NSHostingView(rootView: content)
            window.minSize = NSSize(width: 460, height: 420)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            editorWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        editorWindow?.makeKeyAndOrderFront(nil)
    }

    /// The editor window closed. If the menu sent the user here, bring the menu
    /// back the way it was opened — they asked to edit servers, not to be left
    /// staring at an empty desktop.
    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        let cameFromMenu: Bool
        if closing === editorWindow {
            // Rebuilt on next open so it always matches the current source.
            editorWindow = nil
            cameFromMenu = editorOpenedFromMenu
            editorOpenedFromMenu = false
        } else if closing === settingsWindow {
            cameFromMenu = settingsOpenedFromMenu
            settingsOpenedFromMenu = false
        } else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Still another of our windows up? Then the user isn't done here.
            let stillOpen = (editorWindow?.isVisible ?? false) || (settingsWindow?.isVisible ?? false)
            guard !stillOpen else { return }
            if cameFromMenu {
                panelController.show(anchor: panelController.lastAnchor)
            } else {
                // Opened via ⌘, or the right-click menu: hand focus back to
                // whatever the user came from. Without this ShuttleX stays the
                // active app with no window and keystrokes go nowhere.
                NSApp.hide(nil)
            }
        }
    }

    /// Hide the panel when the user switches to another app (e.g. via ⌘-Tab).
    /// Picker menus inside the panel don't deactivate the app, so they're safe.
    func applicationDidResignActive(_ notification: Notification) {
        panelController?.hide(reason: "app resigned active")
    }
}
