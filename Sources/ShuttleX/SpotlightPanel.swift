import AppKit
import os
import SwiftUI

/// Diagnostics around panel visibility. `.public` on purpose: plain NSLog is
/// redacted to `<private>` in `log stream`, which made remote debugging blind.
/// Logs reasons/coordinates only — never host names or user data.
let panelLog = Logger(subsystem: "com.marek.ShuttleX", category: "panel")

/// A floating panel that can become key (so the search field accepts typing)
/// and closes on Esc. Used as the centered "Spotlight" window.
final class SpotlightPanel: NSPanel {
    /// Called when the user presses Esc (`cancelOperation`).
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}

/// Owns the centered Spotlight panel and shows / hides / toggles it. The panel
/// hosts the same `MenuView` the menu bar used to show, so there is a single
/// code path for both the status-item click and the global hotkey.
@MainActor
final class PanelController {
    private let state: AppState
    private let panel: SpotlightPanel
    private let hostingView: NSHostingView<AnyView>

    /// Bumped on every show so SwiftUI rebuilds the view (re-running `onAppear`,
    /// which clears the search and refocuses the field).
    private var showCount = 0
    /// Monitors clicks outside the app so a click anywhere else dismisses the panel.
    private var outsideClickMonitor: Any?

    /// Opens the Settings window. Set by the app delegate, which owns the window.
    var onOpenSettings: () -> Void = {}
    /// Opens Settings and asks it to show the server editor.
    var onOpenEditor: () -> Void = {}
    /// Whether another of our windows (Settings) is visible — hiding the panel
    /// must not yank the whole app to the background then. Set by the delegate.
    var hasVisibleAuxWindow: () -> Bool = { false }

    init(state: AppState) {
        self.state = state

        let panel = SpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // A frosted, fully rounded background — the Spotlight look.
        let visual = NSVisualEffectView()
        visual.material = .menu
        visual.state = .active
        visual.blendingMode = .behindWindow
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 12
        visual.layer?.masksToBounds = true
        visual.autoresizingMask = [.width, .height]

        let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        hostingView.frame = visual.bounds
        hostingView.autoresizingMask = [.width, .height]
        visual.addSubview(hostingView)

        panel.contentView = visual

        self.panel = panel
        self.hostingView = hostingView
        self.panel.onCancel = { [weak self] in self?.hide(reason: "esc") }
    }

    /// Where the panel appears — preserving both the classic menu-bar dropdown
    /// (mouse users) and the centered Spotlight window (global hotkey).
    enum Anchor {
        /// Anchored just below the menu-bar status item — the original Shuttle feel.
        case statusItem(NSRect)
        /// Centered on the active screen — the power-user hotkey.
        case center
    }

    // MARK: - Visibility

    func toggle(anchor: Anchor) {
        panel.isVisible ? hide(reason: "toggle") : show(anchor: anchor)
    }

    /// How the panel was last opened, so it can be restored the same way
    /// (e.g. after the server editor closes).
    private(set) var lastAnchor: Anchor = .center

    /// Whether the menu is on screen right now. Used to decide where closing a
    /// window should return to — an accessory app only receives ⌘, while one of
    /// its own windows is key, so "was the menu open" is the honest test, not
    /// which button was clicked.
    var isVisible: Bool { panel.isVisible }

    func show(anchor: Anchor) {
        showCount += 1
        lastAnchor = anchor
        let anchorName = { if case .center = anchor { return "center" } else { return "statusItem" } }()
        panelLog.notice("panel show (anchor=\(anchorName, privacy: .public))")
        hostingView.rootView = AnyView(
            MenuView(
                onDismiss: { [weak self] in self?.hide(reason: "menu dismiss") },
                onOpenSettings: { [weak self] in self?.openSettings() },
                onOpenEditor: { [weak self] in self?.onOpenEditor() }
            )
            .environment(state)
            .id(showCount)
        )
        hostingView.layoutSubtreeIfNeeded()
        panel.setContentSize(hostingView.fittingSize)

        switch anchor {
        case .statusItem(let rect): positionAnchored(below: rect)
        case .center: positionCentered()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installOutsideClickMonitor()
    }

    /// Closes the panel. By default it also hands focus back to the previously
    /// active app (`NSApp.hide`) — without this, ShuttleX stays the active app
    /// with no window and keystrokes go nowhere (e.g. hotkey → Esc → typing).
    /// `returnFocus: false` is used when we're about to show our own Settings.
    func hide(returnFocus: Bool = true, reason: String) {
        // Diagnostic: which path closed the panel (visible in `log stream`).
        panelLog.notice("panel hide (reason=\(reason, privacy: .public), returnFocus=\(returnFocus, privacy: .public))")
        removeOutsideClickMonitor()
        panel.orderOut(nil)
        if returnFocus, !hasVisibleAuxWindow() {
            NSApp.hide(nil)
        }
    }

    func openSettings() {
        // The panel is hidden centrally in the delegate's showSettings(), so all
        // entry points (gear, ⌘,, right-click) behave the same.
        onOpenSettings()
    }

    // MARK: - Positioning

    /// Places the panel just below the menu-bar status item, centered under the
    /// icon and clamped to the screen — the classic menu-bar dropdown.
    private func positionAnchored(below anchor: NSRect) {
        guard !anchor.isEmpty else { positionCentered(); return }
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        guard let screen else { positionCentered(); return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let gap: CGFloat = 4
        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = anchor.minY - gap - size.height
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    /// Centers the panel horizontally and places it a little above the vertical
    /// middle of the active screen — the classic Spotlight position.
    private func positionCentered() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 + visible.height * 0.12
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    // MARK: - Click-outside dismissal

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        // A global monitor only fires for events delivered to *other* apps, so
        // clicks inside the panel (and its picker menus) never dismiss it.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return }
            // On managed Macs an invisible overlay window (endpoint tooling) can
            // receive clicks that visually land on our panel — the global monitor
            // then fires even though the user clicked *inside*. Judge by screen
            // position, not by who got the event: inside the panel ⇒ never close.
            let screenPoint = NSEvent.mouseLocation
            if self.panel.frame.contains(screenPoint) {
                panelLog.notice("outside click ignored — inside panel frame (windowNumber=\(event.windowNumber, privacy: .public))")
                return
            }
            panelLog.notice("outside click (windowNumber=\(event.windowNumber, privacy: .public))")
            self.hide(reason: "outside click")
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
