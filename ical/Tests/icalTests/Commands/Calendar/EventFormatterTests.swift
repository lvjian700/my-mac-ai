import Testing
@preconcurrency import EventKit
@testable import ical

@MainActor
struct EventFormatterTests {

    let store = EKEventStore()

    let day1Start = makeDate(year: 2026, month: 4, day: 20, hour: 9,  minute: 0)
    let day1End   = makeDate(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
    let day2Start = makeDate(year: 2026, month: 4, day: 21, hour: 14, minute: 30)
    let day2End   = makeDate(year: 2026, month: 4, day: 21, hour: 15, minute: 0)

    // MARK: - Text format

    @Test func textOutputContainsDateHeader() {
        let event = EKEvent(eventStore: store)
        event.title     = "Morning Standup"
        event.startDate = day1Start
        event.endDate   = day1End
        event.isAllDay  = false

        let output = captureStdout {
            OutputFormatter.printEvents([event], format: .text)
        }

        #expect(output.contains("Mon, 20 Apr 2026"),
                "Expected date header 'Mon, 20 Apr 2026' in:\n\(output)")
    }

    @Test func textOutputContainsTimedEventBullet() {
        let event = EKEvent(eventStore: store)
        event.title     = "Morning Standup"
        event.startDate = day1Start
        event.endDate   = day1End
        event.isAllDay  = false

        let output = captureStdout {
            OutputFormatter.printEvents([event], format: .text)
        }

        #expect(output.contains("  • ") && output.contains("Morning Standup"),
                "Expected timed bullet with title in:\n\(output)")
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let bulletLines = lines.filter { $0.hasPrefix("  • ") }
        #expect(!bulletLines.isEmpty, "Expected at least one bullet line")
        let hasTimed = bulletLines.contains { line in
            line.contains("Morning Standup") && line.contains(":")
        }
        #expect(hasTimed, "Expected time prefix in timed bullet in:\n\(output)")
    }

    @Test func textOutputContainsAllDayBullet() {
        let event = EKEvent(eventStore: store)
        event.title     = "All Day Event"
        event.startDate = makeDate(year: 2026, month: 4, day: 20)
        event.endDate   = makeDate(year: 2026, month: 4, day: 21)
        event.isAllDay  = true

        let output = captureStdout {
            OutputFormatter.printEvents([event], format: .text)
        }

        #expect(output.contains("  • All Day Event ()"),
                "Expected all-day bullet '  • All Day Event ()' in:\n\(output)")
    }

    @Test func textOutputContainsBlankLineBetweenDays() {
        let event1 = EKEvent(eventStore: store)
        event1.title     = "Event Day 1"
        event1.startDate = day1Start
        event1.endDate   = day1End
        event1.isAllDay  = false

        let event2 = EKEvent(eventStore: store)
        event2.title     = "Event Day 2"
        event2.startDate = day2Start
        event2.endDate   = day2End
        event2.isAllDay  = false

        let output = captureStdout {
            OutputFormatter.printEvents([event1, event2], format: .text)
        }

        #expect(output.contains("\n\n"),
                "Expected blank separator line between day groups in:\n\(output)")
    }

    @Test func textOutputEmptyEvents() {
        let output = captureStdout {
            OutputFormatter.printEvents([], format: .text)
        }
        #expect(output.contains("No events found."),
                "Expected 'No events found.' for empty list in:\n\(output)")
    }

    // MARK: - JSON format

    @Test func jsonOutputAllDayEvent() throws {
        let event = EKEvent(eventStore: store)
        event.title     = "Conference Day"
        event.startDate = makeDate(year: 2026, month: 4, day: 20)
        event.endDate   = makeDate(year: 2026, month: 4, day: 21)
        event.isAllDay  = true

        let output = captureStdout {
            OutputFormatter.printEvents([event], format: .json)
        }

        let items = try parseJSONOutput(output)
        #expect(items.count == 1, "Expected 1 JSON item")

        let item = items[0]

        let allDay = item["allDay"] as? Bool
        #expect(allDay == true, "Expected allDay=true, got \(String(describing: item["allDay"]))")

        let start = item["start"] as? String
        #expect(start != nil, "Expected 'start' key")
        #expect(start?.contains("T") == false,
                "All-day start should not contain 'T', got \(start ?? "nil")")
        #expect(start?.hasPrefix("2026-04-20") == true,
                "Expected start '2026-04-20', got \(start ?? "nil")")

        #expect(item["time"] == nil, "All-day event should not have 'time' key")
        #expect(item["date"] != nil, "Expected 'date' key")
        #expect(item["dayOfWeek"] != nil, "Expected 'dayOfWeek' key")
    }

    @Test func jsonOutputTimedEvent() throws {
        let event = EKEvent(eventStore: store)
        event.title     = "Morning Standup"
        event.startDate = day1Start
        event.endDate   = day1End
        event.isAllDay  = false

        let output = captureStdout {
            OutputFormatter.printEvents([event], format: .json)
        }

        let items = try parseJSONOutput(output)
        #expect(items.count == 1, "Expected 1 JSON item")

        let item = items[0]

        let allDay = item["allDay"] as? Bool
        #expect(allDay == false, "Expected allDay=false, got \(String(describing: item["allDay"]))")

        let start = item["start"] as? String
        #expect(start != nil, "Expected 'start' key")
        #expect(start?.contains("T") == true,
                "Timed start should contain 'T', got \(start ?? "nil")")

        let timeDict = item["time"] as? [String: Any]
        #expect(timeDict != nil, "Expected 'time' dictionary for timed event")
        #expect(timeDict?["start"] != nil, "Expected 'time.start' key")
        #expect(timeDict?["end"] != nil, "Expected 'time.end' key")

        #expect(item["date"] != nil, "Expected 'date' key")
        #expect(item["dayOfWeek"] != nil, "Expected 'dayOfWeek' key")
    }

    @Test func jsonOutputAllDayVsTimedBoolTypes() throws {
        let allDayEvent = EKEvent(eventStore: store)
        allDayEvent.title     = "Holiday"
        allDayEvent.startDate = makeDate(year: 2026, month: 4, day: 20)
        allDayEvent.endDate   = makeDate(year: 2026, month: 4, day: 21)
        allDayEvent.isAllDay  = true

        let timedEvent = EKEvent(eventStore: store)
        timedEvent.title     = "Meeting"
        timedEvent.startDate = day1Start
        timedEvent.endDate   = day1End
        timedEvent.isAllDay  = false

        let output = captureStdout {
            OutputFormatter.printEvents([allDayEvent, timedEvent], format: .json)
        }

        let items = try parseJSONOutput(output)
        #expect(items.count == 2, "Expected 2 JSON items")

        let allDayItem = items.first { $0["title"] as? String == "Holiday" }
        let timedItem  = items.first { $0["title"] as? String == "Meeting" }

        #expect(allDayItem != nil, "Expected Holiday item")
        #expect(timedItem  != nil, "Expected Meeting item")

        let allDayBool = allDayItem?["allDay"]
        let timedBool  = timedItem?["allDay"]
        #expect(allDayBool is Bool, "allDay must be Bool type, got \(type(of: allDayBool))")
        #expect(timedBool  is Bool, "allDay must be Bool type, got \(type(of: timedBool))")
        #expect((allDayBool as? Bool) == true,  "Holiday allDay should be true")
        #expect((timedBool  as? Bool) == false, "Meeting allDay should be false")
    }

    @Test func jsonOutputMultipleEvents() throws {
        let event1 = EKEvent(eventStore: store)
        event1.title     = "Event A"
        event1.startDate = day1Start
        event1.endDate   = day1End
        event1.isAllDay  = false

        let event2 = EKEvent(eventStore: store)
        event2.title     = "Event B"
        event2.startDate = day2Start
        event2.endDate   = day2End
        event2.isAllDay  = false

        let output = captureStdout {
            OutputFormatter.printEvents([event1, event2], format: .json)
        }

        let items = try parseJSONOutput(output)
        #expect(items.count == 2, "Expected 2 JSON items for 2 events")

        for item in items {
            #expect(item["date"] != nil,      "Expected 'date' key")
            #expect(item["dayOfWeek"] != nil, "Expected 'dayOfWeek' key")
            #expect(item["title"] != nil,     "Expected 'title' key")
            #expect(item["allDay"] is Bool,   "Expected Bool allDay")
        }
    }
}
