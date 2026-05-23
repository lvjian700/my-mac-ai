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
            ChatView()
                .navigationSplitViewColumnWidth(
                    min: textMetrics.layoutValue(260),
                    ideal: textMetrics.layoutValue(420),
                    max: textMetrics.layoutValue(680)
                )
        } detail: {
            WeekCalendarView()
                .navigationSplitViewColumnWidth(
                    min: textMetrics.layoutValue(480),
                    ideal: textMetrics.layoutValue(680),
                    max: textMetrics.layoutValue(960)
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
