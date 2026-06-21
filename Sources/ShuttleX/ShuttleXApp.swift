import SwiftUI

@main
struct ShuttleXApp: App {
    // The delegate owns the status item, the Spotlight panel, and the global
    // hotkey — and the shared AppState the Settings scene also uses.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The status item, the Spotlight panel, and the Settings window are all
        // managed by the delegate in AppKit. An accessory app still needs one
        // scene, so this stays as an empty, unused Settings scene.
        Settings {
            EmptyView()
        }
    }
}
