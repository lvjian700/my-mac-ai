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
            ChatView()
                .navigationSplitViewColumnWidth(min: 520, ideal: 760)
        } detail: {
            WeekCalendarView()
                .navigationSplitViewColumnWidth(min: 380, ideal: 560, max: 900)
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
