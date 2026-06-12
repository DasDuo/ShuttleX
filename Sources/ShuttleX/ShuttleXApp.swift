import SwiftUI

@main
struct ShuttleXApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environment(state)
        } label: {
            Image(systemName: "terminal.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(state)
        }
    }
}
