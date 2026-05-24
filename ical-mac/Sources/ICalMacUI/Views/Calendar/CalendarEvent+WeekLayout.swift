import Foundation
import ICalMacCore

extension CalendarEvent {
    func intersectsDay(_ day: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return startDate < end && endDate > start
    }
}
