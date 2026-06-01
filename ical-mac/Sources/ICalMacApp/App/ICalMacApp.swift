import AppKit
import EventKit
import ICalMacUI
import SwiftUI

@main
struct ICalMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @State private var textMetrics = preferredReadingTextMetrics()

    var body: some Scene {
        Window("ical-mac", id: "main")  {
            ContentView()
                .environmentObject(model)
                .environment(\.readingTextMetrics, textMetrics)
                .frame(minWidth: 1280, minHeight: 680)
                .task {
                    await model.loadCalendarOnLaunch()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
                    )
                ) { _ in
                    textMetrics = preferredReadingTextMetrics()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
                ) { _ in
                    textMetrics = preferredReadingTextMetrics()
                    model.handleStoreChanged()
                }
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                    model.handleStoreChanged()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) { }
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
                .environment(\.readingTextMetrics, textMetrics)
                .frame(width: 520)
        }
    }
}

// macOS SwiftUI does not resize text from dynamicTypeSize, so read the
// Accessibility > Display > Text Size category and scale app text explicitly.
private func preferredReadingTextMetrics() -> ReadingTextMetrics {
    ReadingTextMetrics(scale: preferredReadingTextScale())
}

private func preferredReadingTextScale() -> CGFloat {
    let category = preferredReadingTextCategory()
    let bodyPointSize = bodyPointSize(for: category)
    return bodyPointSize / 13
}

private func preferredReadingTextCategory() -> String {
    guard let categories = UserDefaults.standard
        .persistentDomain(forName: "com.apple.universalaccess")?["FontSizeCategory"] as? [String: Any]
    else {
        return "M"
    }

    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ai.my-mac.ical-mac"
    let appValue = categories[bundleIdentifier] as? String
    if let appValue, appValue != "UseGlobal" {
        return appValue
    }

    if let globalValue = categories["global"] as? String, globalValue != "UseGlobal" {
        return globalValue
    }

    return "M"
}

private func bodyPointSize(for category: String) -> CGFloat {
    switch category {
    case "XS", "UICTContentSizeCategoryXS":
        11
    case "S", "UICTContentSizeCategoryS":
        12
    case "M", "UICTContentSizeCategoryM", "UICTContentSizeCategoryL":
        13
    case "L", "UICTContentSizeCategoryXL":
        15
    case "XL", "UICTContentSizeCategoryXXL":
        17
    case "XXL", "UICTContentSizeCategoryXXXL":
        19
    case "XXXL":
        21
    case "AX1", "UICTContentSizeCategoryAccessibilityM":
        22
    case "AX2", "UICTContentSizeCategoryAccessibilityL":
        24
    case "AX3", "UICTContentSizeCategoryAccessibilityXL":
        28
    case "AX4", "UICTContentSizeCategoryAccessibilityXXL":
        34
    case "AX5", "UICTContentSizeCategoryAccessibilityXXXL":
        40
    default:
        13
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
