@preconcurrency import EventKit
import Foundation
import ArgumentParser

enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case text, json
}

struct DateParser {
    static func parse(_ string: String) throws -> Date {
        let trimmed = string.trimmingCharacters(in: .whitespaces).lowercased()
        switch trimmed {
        case "today":
            return Calendar.current.startOfDay(for: Date())
        case "tomorrow":
            return Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            )
        default:
            break
        }
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone.current
        if let d = iso.date(from: string) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: string) { return d }
        throw IcalError.invalidDate(string: string)
    }
}

struct OutputFormatter {
    // MARK: - Calendars

    static func printCalendarsGrouped(_ groups: [CalendarGroup], format: OutputFormat) {
        switch format {
        case .text:
            for group in groups {
                print(group.accountName)
                for cal in group.calendars {
                    print("  \(cal.title)")
                }
            }
        case .json:
            let dicts = groups.flatMap { group in
                group.calendars.map { ["account": group.accountName, "title": $0.title] }
            }
            printJSON(dicts)
        }
    }

    // MARK: - Events

    static func printEvents(_ events: [EKEvent], format: OutputFormat) {
        switch format {
        case .text:
            printEventsText(events)
        case .json:
            printEventsJSON(events)
        }
    }

    private static func printEventsText(_ events: [EKEvent]) {
        if events.isEmpty { print("No events found."); return }

        let cal = Calendar.current

        let headerFmt = DateFormatter()
        headerFmt.dateFormat = "EEE, d MMM yyyy"

        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .short

        let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.startDate) }
        let sortedDays = grouped.keys.sorted()

        for (i, day) in sortedDays.enumerated() {
            if i > 0 { print("") }
            print(headerFmt.string(from: day))
            let dayEvents = (grouped[day] ?? []).sorted { $0.startDate < $1.startDate }
            for e in dayEvents {
                let title = e.title ?? "(no title)"
                let calName = e.calendar?.title ?? ""
                if e.isAllDay {
                    print("  • \(title) (\(calName))")
                } else {
                    let time = timeFmt.string(from: e.startDate)
                    print("  • \(time) \(title) (\(calName))")
                }
            }
        }
    }

    private static func printEventsJSON(_ events: [EKEvent]) {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.timeZone = TimeZone.current

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.timeZone = TimeZone.current
        dateFmt.dateFormat = "yyyy-MM-dd"

        let dayOfWeekFmt = DateFormatter()
        dayOfWeekFmt.dateFormat = "EEEE"
        dayOfWeekFmt.timeZone = TimeZone.current

        let hmFmt = DateFormatter()
        hmFmt.locale = Locale(identifier: "en_US_POSIX")
        hmFmt.timeZone = TimeZone.current
        hmFmt.dateFormat = "HH:mm"

        struct TimeRange: Encodable {
            let start: String
            let end: String
        }

        struct EventJSON: Encodable {
            let id: String
            let title: String
            let calendar: String
            let allDay: Bool
            let start: String
            let end: String
            let date: String
            let dayOfWeek: String
            let time: TimeRange?
            let location: String?
            let notes: String?
        }

        let items = events.map { e -> EventJSON in
            let isAllDay = e.isAllDay
            let start = isAllDay ? dateFmt.string(from: e.startDate) : isoFmt.string(from: e.startDate)
            let end = isAllDay ? dateFmt.string(from: e.endDate) : isoFmt.string(from: e.endDate)
            let timeRange = isAllDay ? nil : TimeRange(
                start: hmFmt.string(from: e.startDate),
                end: hmFmt.string(from: e.endDate)
            )
            return EventJSON(
                id: e.eventIdentifier ?? "",
                title: e.title ?? "",
                calendar: e.calendar?.title ?? "",
                allDay: isAllDay,
                start: start,
                end: end,
                date: dateFmt.string(from: e.startDate),
                dayOfWeek: dayOfWeekFmt.string(from: e.startDate),
                time: timeRange,
                location: e.location,
                notes: e.notes
            )
        }
        printJSON(items)
    }

    // MARK: - Helpers

    private static func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}
