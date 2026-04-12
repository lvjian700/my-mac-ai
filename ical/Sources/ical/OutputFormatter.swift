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
        if let d = iso.date(from: string) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: string) { return d }
        throw IcalError.invalidDate(string: string)
    }
}

struct OutputFormatter {
    // MARK: - Calendars

    static func printCalendars(_ calendars: [EKCalendar], format: OutputFormat) {
        switch format {
        case .text:
            printLine("TITLE", width: 30, "TYPE", width: 12, "ID")
            print(String(repeating: "─", count: 74))
            for cal in calendars {
                printLine(cal.title, width: 30, calendarTypeString(cal.type), width: 12, cal.calendarIdentifier)
            }
        case .json:
            let dicts = calendars.map { ["title": $0.title, "type": calendarTypeString($0.type), "id": $0.calendarIdentifier] }
            printJSON(dicts)
        }
    }

    // MARK: - Events

    static func printEvents(_ events: [EKEvent], format: OutputFormat) {
        let df = ISO8601DateFormatter()
        switch format {
        case .text:
            if events.isEmpty { print("No events found."); return }
            printLine("START", width: 22, "TITLE", width: 36, "CALENDAR")
            print(String(repeating: "─", count: 74))
            for e in events {
                let start = e.isAllDay ? formatDate(e.startDate) : df.string(from: e.startDate)
                printLine(start, width: 22, e.title ?? "(no title)", width: 36, e.calendar?.title ?? "")
            }
        case .json:
            let dicts = events.map { e -> [String: String] in
                var d: [String: String] = [
                    "id": e.eventIdentifier ?? "",
                    "title": e.title ?? "",
                    "start": df.string(from: e.startDate),
                    "end": df.string(from: e.endDate),
                    "allDay": e.isAllDay ? "true" : "false",
                    "calendar": e.calendar?.title ?? "",
                ]
                if let loc = e.location { d["location"] = loc }
                if let notes = e.notes { d["notes"] = notes }
                return d
            }
            printJSON(dicts)
        }
    }

    // MARK: - Helpers

    private static func printLine(
        _ c1: String, width w1: Int,
        _ c2: String, width w2: Int,
        _ c3: String
    ) {
        let col1 = truncpad(c1, w1)
        let col2 = truncpad(c2, w2)
        print("\(col1)\(col2)\(c3)")
    }

    private static func truncpad(_ s: String, _ width: Int) -> String {
        s.count > width ? String(s.prefix(width - 1)) + "…" : s.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    private static func calendarTypeString(_ type: EKCalendarType) -> String {
        switch type {
        case .local: return "Local"
        case .calDAV: return "CalDAV"
        case .exchange: return "Exchange"
        case .subscription: return "Subscribed"
        case .birthday: return "Birthday"
        @unknown default: return "Unknown"
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df.string(from: date)
    }

    private static func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}
