import AppKit
import SwiftUI

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
        self.panel.onCancel = { [weak self] in self?.hide() }
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
        panel.isVisible ? hide() : show(anchor: anchor)
    }

    func show(anchor: Anchor) {
        showCount += 1
        hostingView.rootView = AnyView(
            MenuView(
                onDismiss: { [weak self] in self?.hide() },
                onOpenSettings: { [weak self] in self?.openSettings() }
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

    func hide() {
        removeOutsideClickMonitor()
        panel.orderOut(nil)
    }

    func openSettings() {
        hide()
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
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
