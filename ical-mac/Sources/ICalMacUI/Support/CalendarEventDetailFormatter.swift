import Foundation

struct CalendarEventDetailFormatter {
    var calendar: Calendar
    var locale: Locale

    init(calendar: Calendar = .current, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
    }

    func dateTimeText(for event: CalendarEvent) -> String {
        if event.isAllDay {
            return allDayText(for: event)
        }

        if calendar.isDate(event.startDate, inSameDayAs: event.endDate) {
            return "\(dateText(event.startDate)) \(timeText(event.startDate)) – \(timeText(event.endDate))"
        }

        return "\(dateTimeText(event.startDate)) – \(dateTimeText(event.endDate))"
    }

    private func allDayText(for event: CalendarEvent) -> String {
        let start = calendar.startOfDay(for: event.startDate)
        let endStart = calendar.startOfDay(for: event.endDate)
        let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: endStart) ?? event.endDate
        let displayedEnd = max(start, inclusiveEnd)

        if calendar.isDate(start, inSameDayAs: displayedEnd) {
            return dateText(start)
        }

        return "\(dateText(start)) – \(dateText(displayedEnd))"
    }

    private func dateText(_ date: Date) -> String {
        formatter(dateFormat: "d MMM yyyy").string(from: date)
    }

    private func timeText(_ date: Date) -> String {
        formatter(dateFormat: "h:mma").string(from: date)
    }

    private func dateTimeText(_ date: Date) -> String {
        formatter(dateFormat: "d MMM yyyy h:mma").string(from: date)
    }

    private func formatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = dateFormat
        return formatter
    }
}
