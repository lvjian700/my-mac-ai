import Testing
@preconcurrency import EventKit
import Foundation
@testable import ical

// MARK: - Stdout capture helper

/// Redirects stdout to a pipe, runs `body`, then restores stdout and returns the captured string.
@MainActor
func captureStdout(_ body: @MainActor () -> Void) -> String {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    body()

    // Flush Swift's buffered output
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

// MARK: - Test helpers

/// Build a fixed Date from components (local time zone).
func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    return Calendar.current.date(from: comps)!
}

// MARK: - Tests

/// All tests run on the main actor so we can use EKEventStore and captureStdout safely.
@MainActor
struct OutputFormatterTests {

    // Shared store — no calendar access needed just to create EKEvent objects.
    let store = EKEventStore()

    // Fixed dates used across tests:
    //   day1 = 2026-04-20 (Monday)
    //   day2 = 2026-04-21 (Tuesday)
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

        // Header should match "Mon, 20 Apr 2026"
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

        // Timed bullet starts with "  • " followed by a time string then the title
        #expect(output.contains("  • ") && output.contains("Morning Standup"),
                "Expected timed bullet with title in:\n\(output)")
        // Should NOT be an all-day format (no "()" right after title without time prefix)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let bulletLines = lines.filter { $0.hasPrefix("  • ") }
        #expect(!bulletLines.isEmpty, "Expected at least one bullet line")
        // A timed event bullet should contain digits (the time)
        let hasTimed = bulletLines.contains { line in
            line.contains("Morning Standup") &&
            line.contains(":") // time contains colon
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

        // All-day bullet: "  • All Day Event ()"  (calendar is nil → empty string)
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

        // There should be a blank line between the two day groups.
        // "print("")" emits "\n", so we expect "\n\n" somewhere in the output.
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

    /// Parse JSON output into an array of dictionaries.
    private func parseJSONOutput(_ output: String) throws -> [[String: Any]] {
        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data)
        guard let array = parsed as? [[String: Any]] else {
            throw NSError(domain: "Test", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Expected JSON array"])
        }
        return array
    }

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

        // allDay should be Bool true
        let allDay = item["allDay"] as? Bool
        #expect(allDay == true, "Expected allDay=true, got \(String(describing: item["allDay"]))")

        // start should be date-only (yyyy-MM-dd), no 'T'
        let start = item["start"] as? String
        #expect(start != nil, "Expected 'start' key")
        #expect(start?.contains("T") == false,
                "All-day start should not contain 'T', got \(start ?? "nil")")
        #expect(start?.hasPrefix("2026-04-20") == true,
                "Expected start '2026-04-20', got \(start ?? "nil")")

        // Should NOT have a 'time' key
        #expect(item["time"] == nil, "All-day event should not have 'time' key")

        // date and dayOfWeek must be present
        #expect(item["date"] != nil, "Expected 'date' key")
        #expect(item["dayOfWeek"] != nil, "Expected 'dayOfWeek' key")
    }

    @Test func jsonOutputTimedEvent() throws {
        let event = EKEvent(eventStore: store)
        event.title     = "Morning Standup"
        event.startDate = day1Start   // 2026-04-20 09:00
        event.endDate   = day1End     // 2026-04-20 10:00
        event.isAllDay  = false

        let output = captureStdout {
            OutputFormatter.printEvents([event], format: .json)
        }

        let items = try parseJSONOutput(output)
        #expect(items.count == 1, "Expected 1 JSON item")

        let item = items[0]

        // allDay should be Bool false
        let allDay = item["allDay"] as? Bool
        #expect(allDay == false, "Expected allDay=false, got \(String(describing: item["allDay"]))")

        // start should be ISO datetime with 'T'
        let start = item["start"] as? String
        #expect(start != nil, "Expected 'start' key")
        #expect(start?.contains("T") == true,
                "Timed start should contain 'T', got \(start ?? "nil")")

        // time dictionary with start and end keys
        let timeDict = item["time"] as? [String: Any]
        #expect(timeDict != nil, "Expected 'time' dictionary for timed event")
        #expect(timeDict?["start"] != nil, "Expected 'time.start' key")
        #expect(timeDict?["end"] != nil, "Expected 'time.end' key")

        // date and dayOfWeek must be present
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

        // Find by title
        let allDayItem = items.first { $0["title"] as? String == "Holiday" }
        let timedItem  = items.first { $0["title"] as? String == "Meeting" }

        #expect(allDayItem != nil, "Expected Holiday item")
        #expect(timedItem  != nil, "Expected Meeting item")

        // allDay field must be actual Bool, not a string
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
