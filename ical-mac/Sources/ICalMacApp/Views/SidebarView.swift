import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem.ID?

    private let items: [SidebarItem] = [.chat, .calendar]

    var body: some View {
        List(selection: $selection) {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .lineLimit(1)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .tag(item.id)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ical-mac")
    }
}
