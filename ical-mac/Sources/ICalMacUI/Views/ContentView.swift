import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppModel.preview())
        .frame(width: 1400, height: 760)
}
#endif

public struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CalendarsSidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            ChatView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 420, max: 680)
        } detail: {
            WeekCalendarView()
                .navigationSplitViewColumnWidth(min: 480, ideal: 680, max: 960)
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
