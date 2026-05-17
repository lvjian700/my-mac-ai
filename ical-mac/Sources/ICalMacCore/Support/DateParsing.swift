import Foundation

public enum DateParsingError: LocalizedError, Equatable {
    case invalidDate(String)
    case invalidRange

    public var errorDescription: String? {
        switch self {
        case .invalidDate(let value):
            return "Cannot parse date '\(value)'. Use YYYY-MM-DD or ISO-8601."
        case .invalidRange:
            return "End date must be after start date."
        }
    }
}

public struct CalendarDateParser: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func parse(_ value: String, endOfDay: Bool = false, now: Date = Date()) throws -> Date {
        let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower == "today" {
            return boundary(for: now, endOfDay: endOfDay)
        }
        if lower == "tomorrow" {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return boundary(for: tomorrow, endOfDay: endOfDay)
        }

        if let date = Self.iso8601Formatter(options: [.withInternetDateTime, .withFractionalSeconds]).date(from: value)
            ?? Self.iso8601Formatter(options: [.withInternetDateTime]).date(from: value) {
            return date
        }

        if let date = Self.dateOnlyFormatter().date(from: value) {
            return boundary(for: date, endOfDay: endOfDay)
        }

        throw DateParsingError.invalidDate(value)
    }

    public func query(from fromValue: String, to toValue: String, now: Date = Date()) throws -> CalendarQuery {
        let start = try parse(fromValue, now: now)
        let end = try parse(toValue, endOfDay: true, now: now)
        guard end > start else { throw DateParsingError.invalidRange }
        return CalendarQuery(startDate: start, endDate: end)
    }

    private func boundary(for date: Date, endOfDay: Bool) -> Date {
        let start = calendar.startOfDay(for: date)
        if !endOfDay { return start }
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? start
    }

    private static func dateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func iso8601Formatter(options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter
    }
}
