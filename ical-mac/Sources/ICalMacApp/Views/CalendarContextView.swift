import ICalMacCore
import SwiftUI

struct CalendarContextView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StatusPanel()
                UpcomingEventsPanel(events: model.events)
                CalendarsPanel(calendars: model.calendars)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Calendar")
    }
}

private struct StatusPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Status", systemImage: "checkmark.circle")
                .font(.headline)
            Text(model.statusText)
                .foregroundStyle(.secondary)
            Text("Calendar access: \(model.accessStatus.rawValue)")
                .foregroundStyle(.secondary)
            if !model.hasAPIKey {
                Text("Add an Anthropic API key in Settings before chatting.")
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }
}

private struct UpcomingEventsPanel: View {
    let events: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Upcoming", systemImage: "calendar.badge.clock")
                .font(.headline)

            if events.isEmpty {
                Text("No events loaded.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events.prefix(20)) { event in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .lineLimit(1)
                            Text("\(event.calendarTitle) · \(Self.intervalFormatter.string(from: event.startDate, to: event.endDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    Divider()
                }
            }
        }
        .panelStyle()
    }

    private static let intervalFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct CalendarsPanel: View {
    let calendars: [CalendarInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Calendars", systemImage: "rectangle.stack")
                .font(.headline)

            if calendars.isEmpty {
                Text("No calendars loaded.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(calendars) { calendar in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calendar.title)
                            Text(calendar.accountName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !calendar.allowsContentModifications {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .panelStyle()
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
