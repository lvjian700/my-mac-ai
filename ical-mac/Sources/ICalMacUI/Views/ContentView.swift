import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppModel.preview())
        .frame(width: 800, height: 600)
}
#endif

public struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CalendarsSidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } content: {
            WeekCalendarView()
                .navigationSplitViewColumnWidth(min: 520, ideal: 780)
        } detail: {
            ChatView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 460)
        }
        .onAppear {
            model.startAutoRefresh()
        }
        .onDisappear {
            model.stopAutoRefresh()
        }
        .hidesVisibleWindowTitle()
    }
}
