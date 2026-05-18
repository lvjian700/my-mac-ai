import AppKit
import SwiftUI

@main
struct ICalMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
