import CoreGraphics
import Foundation
import ICalMacCore

struct TimedEventLayoutFrame: Identifiable, Equatable {
    let id: String
    let event: CalendarEvent
    let weekOccurrenceID: String
    let dayIndex: Int
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

enum TimedEventWeekLayout {
    static func frames(
        for events: [CalendarEvent],
        weekStartDate: Date,
        calendar: Calendar,
        dayWidth: CGFloat,
        timeColumnWidth: CGFloat,
        hourHeight: CGFloat,
        eventHorizontalInset: CGFloat,
        laneGap: CGFloat
    ) -> [TimedEventLayoutFrame] {
        let weekStart = calendar.startOfDay(for: weekStartDate)
        let inputs = layoutInputs(
            for: events,
            weekStart: weekStart,
            calendar: calendar,
            hourHeight: hourHeight
        )
        let inputsByDay = Dictionary(grouping: inputs, by: \.dayIndex)

        return inputsByDay
            .keys
            .sorted()
            .flatMap { dayIndex in
                frames(
                    for: inputsByDay[dayIndex] ?? [],
                    dayIndex: dayIndex,
                    dayWidth: dayWidth,
                    timeColumnWidth: timeColumnWidth,
                    eventHorizontalInset: eventHorizontalInset,
                    laneGap: laneGap
                )
            }
    }

    private static func layoutInputs(
        for events: [CalendarEvent],
        weekStart: Date,
        calendar: Calendar,
        hourHeight: CGFloat
    ) -> [TimedEventLayoutInput] {
        let minuteHeight = hourHeight / 60
        let minimumEventHeight = minuteHeight * 5

        return events.flatMap { event in
            (0..<7).compactMap { dayIndex -> TimedEventLayoutInput? in
                let dayStart = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
                let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                let visibleStart = max(event.startDate, dayStart)
                let visibleEnd = min(event.endDate, nextDay)
                guard visibleStart < visibleEnd else { return nil }

                let startOffset = minuteOffset(from: dayStart, to: visibleStart, calendar: calendar)
                let duration = minuteOffset(from: visibleStart, to: visibleEnd, calendar: calendar)
                let gridHeight = hourHeight * 24
                let startY = CGFloat(startOffset) * minuteHeight
                let durationHeight = CGFloat(duration) * minuteHeight
                let clampedHeight = min(max(durationHeight, minimumEventHeight), gridHeight)
                let clampedY = min(max(startY, 0), max(gridHeight - clampedHeight, 0))

                return TimedEventLayoutInput(
                    event: event,
                    dayIndex: dayIndex,
                    visibleStart: visibleStart,
                    visibleEnd: visibleEnd,
                    y: clampedY,
                    height: clampedHeight
                )
            }
        }
    }

    private static func minuteOffset(from startDate: Date, to endDate: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.minute], from: startDate, to: endDate)
        return max(components.minute ?? 0, 0)
    }

    private static func frames(
        for inputs: [TimedEventLayoutInput],
        dayIndex: Int,
        dayWidth: CGFloat,
        timeColumnWidth: CGFloat,
        eventHorizontalInset: CGFloat,
        laneGap: CGFloat
    ) -> [TimedEventLayoutFrame] {
        collisionGroups(for: inputs).flatMap { group in
            frames(
                forCollisionGroup: group,
                dayIndex: dayIndex,
                dayWidth: dayWidth,
                timeColumnWidth: timeColumnWidth,
                eventHorizontalInset: eventHorizontalInset,
                laneGap: laneGap
            )
        }
    }

    private static func collisionGroups(for inputs: [TimedEventLayoutInput]) -> [[TimedEventLayoutInput]] {
        let sortedInputs = inputs.sorted(by: layoutOrder)
        var groups: [[TimedEventLayoutInput]] = []
        var currentGroup: [TimedEventLayoutInput] = []
        var currentGroupEnd: Date?

        for input in sortedInputs {
            if let groupEnd = currentGroupEnd, input.visibleStart < groupEnd {
                currentGroup.append(input)
                currentGroupEnd = max(groupEnd, input.visibleEnd)
            } else {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [input]
                currentGroupEnd = input.visibleEnd
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        return groups
    }

    private static func frames(
        forCollisionGroup group: [TimedEventLayoutInput],
        dayIndex: Int,
        dayWidth: CGFloat,
        timeColumnWidth: CGFloat,
        eventHorizontalInset: CGFloat,
        laneGap: CGFloat
    ) -> [TimedEventLayoutFrame] {
        let assignments = laneAssignments(for: group)
        let laneCount = max((assignments.map(\.lane).max() ?? 0) + 1, 1)
        let availableWidth = max(dayWidth - eventHorizontalInset, 0)
        let laneWidth = availableWidth / CGFloat(laneCount)

        return assignments.map { assignment in
            let width = max(laneWidth - laneGap, 0)
            let x = timeColumnWidth
                + CGFloat(dayIndex) * dayWidth
                + eventHorizontalInset
                + CGFloat(assignment.lane) * laneWidth

            return TimedEventLayoutFrame(
                id: "\(assignment.input.weekOccurrenceID)-day-\(dayIndex)",
                event: assignment.input.event,
                weekOccurrenceID: assignment.input.weekOccurrenceID,
                dayIndex: dayIndex,
                x: x,
                y: assignment.input.y,
                width: width,
                height: assignment.input.height
            )
        }
        .sorted { first, second in
            layoutOrder(first.event, second.event)
        }
    }

    private static func laneAssignments(for group: [TimedEventLayoutInput]) -> [TimedEventLaneAssignment] {
        var laneEndDates: [Date] = []
        var assignments: [TimedEventLaneAssignment] = []

        for input in group.sorted(by: layoutOrder) {
            let lane = laneEndDates.firstIndex { $0 <= input.visibleStart } ?? laneEndDates.count
            if lane == laneEndDates.count {
                laneEndDates.append(input.visibleEnd)
            } else {
                laneEndDates[lane] = input.visibleEnd
            }
            assignments.append(TimedEventLaneAssignment(input: input, lane: lane))
        }

        return assignments
    }

    private static func layoutOrder(_ first: TimedEventLayoutInput, _ second: TimedEventLayoutInput) -> Bool {
        if first.visibleStart != second.visibleStart {
            return first.visibleStart < second.visibleStart
        }
        if first.visibleEnd != second.visibleEnd {
            return first.visibleEnd < second.visibleEnd
        }
        return first.weekOccurrenceID < second.weekOccurrenceID
    }

    private static func layoutOrder(_ first: CalendarEvent, _ second: CalendarEvent) -> Bool {
        if first.startDate != second.startDate {
            return first.startDate < second.startDate
        }
        if first.endDate != second.endDate {
            return first.endDate < second.endDate
        }
        return first.weekOccurrenceID < second.weekOccurrenceID
    }
}

private struct TimedEventLayoutInput {
    let event: CalendarEvent
    let dayIndex: Int
    let visibleStart: Date
    let visibleEnd: Date
    let y: CGFloat
    let height: CGFloat

    var weekOccurrenceID: String {
        event.weekOccurrenceID
    }
}

private struct TimedEventLaneAssignment {
    let input: TimedEventLayoutInput
    let lane: Int
}
