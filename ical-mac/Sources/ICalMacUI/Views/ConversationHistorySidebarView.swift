import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    ConversationHistorySidebarView()
        .environmentObject(AppModel.preview())
        .frame(width: 400, height: 560)
}
#endif

struct ConversationHistorySidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section("Conversations") {
                ForEach(model.conversationSummaries) { summary in
                    ConversationHistoryRow(
                        summary: summary,
                        isSelected: model.selectedConversationID == summary.id
                    )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !model.isSending, model.selectedConversationID != summary.id else { return }
                            Task { await model.selectConversation(id: summary.id) }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await model.deleteConversation(id: summary.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(model.isSending)
                        }
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: 0,
                            bottom: 0,
                            trailing: 0
                        ))
                        .listRowBackground(
                            ConversationHistoryRowBackground(
                                isSelected: model.selectedConversationID == summary.id
                            )
                        )
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
    }
}

private struct SidebarFooter: View {
    @EnvironmentObject private var model: AppModel

    private var footerSpacing: CGFloat { 8 }
    private var horizontalPadding: CGFloat { 14 }
    private var verticalPadding: CGFloat { 12 }

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
        .font(.callout)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(.bar)
    }
}

private struct ConversationHistoryRow: View {
    let summary: ConversationSummary
    let isSelected: Bool

    private var rowSpacing: CGFloat { 4 }
    private var horizontalPadding: CGFloat { 0 }
    private var verticalPadding: CGFloat { 6 }
    private var timeWidth: CGFloat { 40 }
    private let relativeTimeFormatter = CompactRelativeTimeFormatter()

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            HStack(alignment: .firstTextBaseline, spacing: rowSpacing) {
                Text(summary.title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                Text(relativeTimeFormatter.string(from: summary.updatedAt, relativeTo: context.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .monospacedDigit()
                    .frame(minWidth: timeWidth, alignment: .trailing)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .help(summary.lastMessagePreview)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct ConversationHistoryRowBackground: View {
    let isSelected: Bool

    private var cornerRadius: CGFloat { 7 }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isSelected ? Color.secondary.opacity(0.12) : Color.clear)
            .padding(.horizontal, 6)
    }
}
