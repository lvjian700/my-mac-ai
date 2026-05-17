import Foundation

@MainActor
public struct SessionSnapshotBuilder {
    private let calendarStore: CalendarStore
    private let calendar: Calendar

    public init(calendarStore: CalendarStore, calendar: Calendar = .current) {
        self.calendarStore = calendarStore
        self.calendar = calendar
    }

    public func currentTwoWeekSnapshot(now: Date = Date()) throws -> SessionSnapshot {
        let range = twoWeekRange(now: now)
        let events = try calendarStore.listEvents(range: range)
        return SessionSnapshot(events: events, syncedAt: Date(), range: range)
    }

    public func twoWeekRange(now: Date = Date()) -> CalendarQuery {
        let day = calendar.component(.weekday, from: now)
        let daysFromMonday = day == 1 ? 6 : day - 2
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now)) ?? now
        let nextSunday = calendar.date(byAdding: .day, value: 13, to: monday) ?? monday
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: nextSunday) ?? nextSunday
        return CalendarQuery(startDate: monday, endDate: end)
    }
}
