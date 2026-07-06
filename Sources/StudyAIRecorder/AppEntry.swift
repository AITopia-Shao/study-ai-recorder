import SwiftUI

@main
struct StudyAIRecorderApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Trace") {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 1080, minHeight: 720)
                .preferredColorScheme(state.database.settings.visualTheme.preferredColorScheme)
        }

        Settings {
            SettingsView()
                .environmentObject(state)
                .frame(width: 620, height: 520)
                .preferredColorScheme(state.database.settings.visualTheme.preferredColorScheme)
        }
    }
}
