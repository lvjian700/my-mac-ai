import Foundation
import ICalMacCore
import Testing
@testable import ICalMacUI

struct CalendarEventDetailFormatterTests {
    @Test func formatsSameDayTimedEvent() {
        let event = CalendarEvent(
            id: "workout",
            title: "Workout",
            startDate: makeDetailDate(year: 2026, month: 5, day: 23, hour: 19, minute: 30),
            endDate: makeDetailDate(year: 2026, month: 5, day: 23, hour: 20),
            isAllDay: false,
            calendarTitle: "Personal"
        )

        #expect(formatter.dateTimeText(for: event) == "23 May 2026 7:30PM – 8:00PM")
    }

    @Test func formatsMultiDayTimedEvent() {
        let event = CalendarEvent(
            id: "overnight",
            title: "Overnight",
            startDate: makeDetailDate(year: 2026, month: 5, day: 23, hour: 23, minute: 30),
            endDate: makeDetailDate(year: 2026, month: 5, day: 24, hour: 0, minute: 30),
            isAllDay: false,
            calendarTitle: "Work"
        )

        #expect(formatter.dateTimeText(for: event) == "23 May 2026 11:30PM – 24 May 2026 12:30AM")
    }

    @Test func formatsSingleDayAllDayEvent() {
        let event = CalendarEvent(
            id: "holiday",
            title: "Holiday",
            startDate: makeDetailDate(year: 2026, month: 5, day: 23),
            endDate: makeDetailDate(year: 2026, month: 5, day: 24),
            isAllDay: true,
            calendarTitle: "Holidays"
        )

        #expect(formatter.dateTimeText(for: event) == "23 May 2026")
    }

    @Test func formatsMultiDayAllDayEventWithExclusiveEndDate() {
        let event = CalendarEvent(
            id: "conference",
            title: "Conference",
            startDate: makeDetailDate(year: 2026, month: 5, day: 23),
            endDate: makeDetailDate(year: 2026, month: 5, day: 26),
            isAllDay: true,
            calendarTitle: "Work"
        )

        #expect(formatter.dateTimeText(for: event) == "23 May 2026 – 25 May 2026")
    }

    private var formatter: CalendarEventDetailFormatter {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return CalendarEventDetailFormatter(
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

private func makeDetailDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0
) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    return components.date!
}
