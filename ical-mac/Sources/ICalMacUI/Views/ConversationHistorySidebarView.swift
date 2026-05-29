import SwiftUI

#if DEBUG
#Preview {
    ConversationHistorySidebarView()
        .environmentObject(AppModel.preview())
        .frame(width: 260, height: 560)
}
#endif

struct ConversationHistorySidebarView: View {
    @Environment(\.readingTextMetrics) private var textMetrics

    var body: some View {
        List {
            Section("Conversations") {
                ConversationHistoryRow(title: "Current conversation")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Cali")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter()
        }
    }
}

private struct SidebarFooter: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.readingTextMetrics) private var textMetrics

    private var footerSpacing: CGFloat { textMetrics.layoutValue(8) }
    private var horizontalPadding: CGFloat { textMetrics.layoutValue(14) }
    private var verticalPadding: CGFloat { textMetrics.layoutValue(12) }

    var body: some View {
        VStack(alignment: .leading, spacing: footerSpacing) {
            Divider()

            Label(model.statusText, systemImage: model.isRefreshing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if model.isShowingCachedSnapshot {
                Label("Showing cached events", systemImage: "externaldrive")
                    .foregroundStyle(.secondary)
            }

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help("Open Settings")
        }
        .font(textMetrics.font(.callout))
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(.bar)
    }
}

private struct ConversationHistoryRow: View {
    let title: String
    @Environment(\.readingTextMetrics) private var textMetrics

    private var rowSpacing: CGFloat { textMetrics.layoutValue(8) }
    private var titleSpacing: CGFloat { textMetrics.layoutValue(2) }

    var body: some View {
        HStack(spacing: rowSpacing) {
            Image(systemName: "message")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: titleSpacing) {
                Text(title)
                    .font(textMetrics.font(.body))
                    .lineLimit(1)
            }
        }
    }
}
