import SwiftUI

@main
struct ICalMacApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("ical-mac") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 620)
                .task {
                    await model.loadCalendarOnLaunch()
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Calendar") {
                    Task { await model.refreshCalendar() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 520)
        }
    }
}
