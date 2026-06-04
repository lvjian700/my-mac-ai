import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    ConversationHistorySidebarView()
        .environmentObject(AppModel.preview())
        .frame(width: 260, height: 560)
}
#endif

struct ConversationHistorySidebarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: UUID?
    @Environment(\.readingTextMetrics) private var textMetrics

    var body: some View {
        List(selection: $selection) {
            Section("Conversations") {
                ForEach(model.conversationSummaries) { summary in
                    ConversationHistoryRow(summary: summary)
                        .tag(summary.id)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await model.deleteConversation(id: summary.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(model.isSending)
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Cali")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await model.createNewConversation() }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(model.isSending)
                .help("New conversation")

                Button(role: .destructive) {
                    if let id = model.selectedConversationID {
                        Task { await model.deleteConversation(id: id) }
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(model.isSending || model.selectedConversationID == nil)
                .help("Delete conversation")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter()
        }
        .onChange(of: selection) { _, newID in
            guard let newID, newID != model.selectedConversationID else { return }
            Task {
                await model.selectConversation(id: newID)
                if model.selectedConversationID != newID {
                    selection = model.selectedConversationID
                }
            }
        }
        .onChange(of: model.selectedConversationID) { _, newID in
            selection = newID
        }
        .onAppear { selection = model.selectedConversationID }
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
    let summary: ConversationSummary
    @Environment(\.readingTextMetrics) private var textMetrics

    private var rowSpacing: CGFloat { textMetrics.layoutValue(8) }
    private var titleSpacing: CGFloat { textMetrics.layoutValue(3) }

    var body: some View {
        HStack(spacing: rowSpacing) {
            Image(systemName: "message")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: titleSpacing) {
                Text(summary.title)
                    .font(textMetrics.font(.body))
                    .lineLimit(1)

                Text(summary.lastMessagePreview)
                    .font(textMetrics.font(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
