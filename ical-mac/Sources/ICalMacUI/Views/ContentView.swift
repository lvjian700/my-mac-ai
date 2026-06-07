import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppModel.preview(events: PreviewData.events))
        .frame(width: 1400, height: 920)
}
#endif

public struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ConversationHistorySidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            ChatView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 480)
        } detail: {
            WeekCalendarView()
                .navigationSplitViewColumnWidth(min: 760, ideal: 980, max: 1440)
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
