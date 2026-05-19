import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    CalendarsSidebarView()
        .environmentObject(AppModel.preview())
        .frame(width: 260, height: 560)
}
#endif

struct CalendarsSidebarView: View {
    @EnvironmentObject private var model: AppModel

    private var accountGroups: [(account: String, calendars: [CalendarInfo])] {
        let grouped = Dictionary(grouping: model.calendars, by: \.accountName)
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { account in
                (
                    account,
                    grouped[account, default: []].sorted {
                        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                )
            }
    }

    var body: some View {
        List {
            if accountGroups.isEmpty {
                Section("Calendars") {
                    Text("No calendars loaded")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(accountGroups, id: \.account) { group in
                    Section(group.account) {
                        ForEach(group.calendars) { calendar in
                            CalendarToggleRow(calendar: calendar, isSelected: binding(for: calendar))
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Cali")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter()
        }
    }

    private func binding(for calendar: CalendarInfo) -> Binding<Bool> {
        Binding {
            model.selectedCalendarIDs.contains(calendar.id)
        } set: { isSelected in
            model.setCalendar(id: calendar.id, isSelected: isSelected)
        }
    }
}

private struct SidebarFooter: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct CalendarToggleRow: View {
    let calendar: CalendarInfo
    @Binding var isSelected: Bool

    private var color: Color {
        Color(calendarHex: calendar.colorHex) ?? .accentColor
    }

    var body: some View {
        Toggle(isOn: $isSelected) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .lineLimit(1)
                }

                if !calendar.allowsContentModifications {
                    Spacer(minLength: 4)
                    Image(systemName: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Read-only calendar")
                }
            }
        }
        .toggleStyle(.checkbox)
    }
}
