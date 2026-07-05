import SwiftUI

@main
struct StudyAIRecorderApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 1080, minHeight: 720)
                .preferredColorScheme(state.database.settings.visualTheme.preferredColorScheme)
        }
        .commands {
            CommandMenu("记录") {
                Button(state.monitor.isRunning ? "停止监控" : "开始监控") {
                    if state.monitor.isRunning {
                        state.monitor.stop()
                    } else {
                        state.monitor.start()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("生成今日 AI 总结") {
                    Task {
                        await state.generateSummary()
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(state)
                .frame(width: 620, height: 520)
                .preferredColorScheme(state.database.settings.visualTheme.preferredColorScheme)
        }
    }
}
