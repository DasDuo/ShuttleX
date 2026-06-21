import AppKit
import KeyboardShortcuts
import SwiftUI

/// A minimal shortcut recorder built on KeyboardShortcuts' public API.
///
/// We deliberately avoid `KeyboardShortcuts.Recorder`: its AppKit view touches
/// the package's `Bundle.module`, whose SwiftPM accessor only looks next to the
/// executable / at a hard-coded build path — neither exists in our hand-built,
/// code-signed `.app`, so it fatal-errors (crash on opening Settings). The core
/// API used here never touches `Bundle.module`.
struct HotkeyRecorder: View {
    let name: KeyboardShortcuts.Name

    @State private var shortcut: KeyboardShortcuts.Shortcut?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggle) {
                Text(label)
                    .frame(minWidth: 150)
                    .contentShape(Rectangle())
            }
            .help(recording ? "Press a key combination, or Esc to cancel" : "Click to record a shortcut")

            if shortcut != nil, !recording {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
            }
        }
        .onAppear { shortcut = KeyboardShortcuts.getShortcut(for: name) }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if recording { return "Press keys…" }
        return shortcut?.description ?? "Record Shortcut"
    }

    private func toggle() { recording ? stop() : start() }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { stop(); return nil }        // Esc cancels
            if event.keyCode == 51 { clear(); stop(); return nil } // Delete clears
            if let new = KeyboardShortcuts.Shortcut(event: event) {
                KeyboardShortcuts.setShortcut(new, for: name)
                shortcut = new
                stop()
            }
            return nil // swallow the event while recording
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func clear() {
        KeyboardShortcuts.setShortcut(nil, for: name)
        shortcut = nil
    }
}
