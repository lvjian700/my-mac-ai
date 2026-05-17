import ICalMacCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @SceneStorage("ical-mac.selection") private var selection: SidebarItem.ID?

    var body: some View {
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

struct SidebarItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String

    static let chat = SidebarItem(id: "chat", title: "Assistant", detail: "Calendar chat", systemImage: "message")
    static let calendar = SidebarItem(id: "calendar", title: "Calendar", detail: "Upcoming context", systemImage: "calendar")
}
