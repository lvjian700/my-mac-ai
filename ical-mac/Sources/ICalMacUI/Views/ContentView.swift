import ICalMacCore
import SwiftUI

#Preview {
    ContentView()
        .environmentObject(AppModel.preview())
        .frame(width: 800, height: 600)
}

public struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @SceneStorage("ical-mac.selection") private var selection: SidebarItem.ID?

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection ?? SidebarItem.chat.id {
            case SidebarItem.chat.id:
                ChatView()
            case SidebarItem.calendar.id:
                CalendarContextView()
            default:
                ChatView()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await model.refreshCalendar() }
                } label: {
                    Label("Refresh Calendar", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshing)

                Button {
                    model.clearChat()
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
            }
        }
    }
}

public struct SidebarItem: Identifiable, Hashable, Sendable {
    public let id: String
    let title: String
    let detail: String
    let systemImage: String

    public static let chat = SidebarItem(id: "chat", title: "Assistant", detail: "Calendar chat", systemImage: "message")
    public static let calendar = SidebarItem(id: "calendar", title: "Calendar", detail: "Upcoming context", systemImage: "calendar")
}
