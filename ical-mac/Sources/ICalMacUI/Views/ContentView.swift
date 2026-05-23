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
    @Environment(\.readingTextMetrics) private var textMetrics
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CalendarsSidebarView()
                .navigationSplitViewColumnWidth(
                    min: textMetrics.layoutValue(180),
                    ideal: textMetrics.layoutValue(220),
                    max: textMetrics.layoutValue(300)
                )
        } content: {
            WeekCalendarView()
                .navigationSplitViewColumnWidth(
                    min: textMetrics.layoutValue(480),
                    ideal: textMetrics.layoutValue(720),
                    max: textMetrics.layoutValue(960)
                    
                )
        } detail: {
            ChatView()
                .navigationSplitViewColumnWidth(
                    min: textMetrics.layoutValue(240),
                    ideal: textMetrics.layoutValue(280),
                    max: textMetrics.layoutValue(480)
                )
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
