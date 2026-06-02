import Foundation
import Testing
@testable import ICalMacUI
import ICalMacCore

struct TimedEventWeekLayoutTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test func threeFullyOverlappingEventsUseThreeSideBySideLanes() {
        let frames = layoutFrames(for: [
            event(id: "a", startHour: 15, endHour: 16),
            event(id: "b", startHour: 15, endHour: 16),
            event(id: "c", startHour: 15, endHour: 16),
        ])

        #expect(frames.map(\.event.id) == ["a", "b", "c"])
        #expect(frames.map(\.dayIndex) == [0, 0, 0])
        #expect(isNearlyEqual(frames[0].x, 1))
        #expect(isNearlyEqual(frames[1].x, 100.66666666666667))
        #expect(isNearlyEqual(frames[2].x, 200.33333333333334))
        #expect(frames.allSatisfy { isNearlyEqual($0.width, 97.66666666666667) })
    }

    @Test func partiallyOverlappingEventsShareLanesAndPreserveStrictClashes() {
        let frames = layoutFrames(for: [
            event(id: "a", startHour: 15, endHour: 17),
            event(id: "b", startHour: 16, endHour: 18),
            event(id: "c", startHour: 17, endHour: 18),
        ])

        #expect(frames.map(\.event.id) == ["a", "b", "c"])
        #expect(isNearlyEqual(frames[0].x, 1))
        #expect(isNearlyEqual(frames[1].x, 150.5))
        #expect(isNearlyEqual(frames[2].x, 1))
        #expect(frames.allSatisfy { isNearlyEqual($0.width, 147.5) })
    }

    @Test func collisionGroupKeepsEqualLaneWidthWithoutExpansion() {
        let frames = layoutFrames(for: [
            event(id: "a", startHour: 15, endHour: 18),
            event(id: "b", startHour: 15, startMinute: 30, endHour: 16, endMinute: 30),
            event(id: "c", startHour: 15, startMinute: 45, endHour: 16),
            event(id: "d", startHour: 16, startMinute: 30, endHour: 17, endMinute: 30),
        ])
        let expanded = frames.first { $0.event.id == "d" }

        #expect(isNearlyEqual(expanded?.x, 100.66666666666667))
        #expect(isNearlyEqual(expanded?.width, 97.66666666666667))
    }

    @Test func adjacentEventsDoNotShareCollisionGroup() {
        let frames = layoutFrames(for: [
            event(id: "a", startHour: 15, endHour: 16),
            event(id: "b", startHour: 16, endHour: 17),
        ])

        #expect(frames.map(\.event.id) == ["a", "b"])
        #expect(frames.map(\.x) == [1, 1])
        #expect(frames.map(\.width) == [297, 297])
    }

    @Test func multiDayTimedEventIsClippedIntoVisibleDays() {
        let frames = layoutFrames(for: [
            CalendarEvent(
                id: "multi",
                title: "Multi-day",
                startDate: makeDate(day: 18, hour: 23),
                endDate: makeDate(day: 19, hour: 1),
                isAllDay: false,
                calendarTitle: "Work"
            ),
        ])

        #expect(frames.count == 2)
        #expect(frames.map(\.dayIndex) == [0, 1])
        #expect(frames.map(\.y) == [23 * 60 + 1, 1])
        #expect(frames.map(\.height) == [58, 58])
    }

    @Test func sameStartEventsUseStableIDOrdering() {
        let frames = layoutFrames(for: [
            event(id: "c", startHour: 15, endHour: 16),
            event(id: "a", startHour: 15, endHour: 16),
            event(id: "b", startHour: 15, endHour: 16),
        ])

        #expect(frames.map(\.event.id) == ["a", "b", "c"])
    }

    private func layoutFrames(for events: [CalendarEvent]) -> [TimedEventLayoutFrame] {
        TimedEventWeekLayout.frames(
            for: events,
            weekStartDate: makeDate(day: 18),
            calendar: calendar,
            dayWidth: 300,
            timeColumnWidth: 0,
            hourHeight: 60,
            eventHorizontalInset: 1,
            eventVerticalInset: 1,
            minimumEventHeight: 28,
            laneGap: 2
        )
    }

    private func event(
        id: String,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: id,
            startDate: makeDate(day: 18, hour: startHour, minute: startMinute),
            endDate: makeDate(day: 18, hour: endHour, minute: endMinute),
            isAllDay: false,
            calendarTitle: "Work"
        )
    }

    private func makeDate(day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }

    private func isNearlyEqual(_ actual: CGFloat?, _ expected: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
        guard let actual else { return false }
        return abs(actual - expected) <= tolerance
    }
}
