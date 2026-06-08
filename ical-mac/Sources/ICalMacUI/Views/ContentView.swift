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
    @Environment(\.readingTextMetrics) private var textMetrics
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ConversationHistorySidebarView()
                .navigationSplitViewColumnWidth(
                    min: textMetrics.layoutValue(200),
                    ideal: textMetrics.layoutValue(240),
                    max: textMetrics.layoutValue(320)
                )
        } content: {
            ChatView()
                .navigationSplitViewColumnWidth(
                    min: textMetrics.layoutValue(240),
                    ideal: textMetrics.layoutValue(280),
                    max: textMetrics.layoutValue(480)
                )
            
        } detail: {
            WeekCalendarView()
                .navigationSplitViewColumnWidth(
                    min: textMetrics.layoutValue(760),
                    ideal: textMetrics.layoutValue(980),
                    max: textMetrics.layoutValue(1440)
                    
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
