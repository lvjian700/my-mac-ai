import Foundation
import Testing
@testable import ICalMacCore

@MainActor
struct CalendarToolExecutorTests {
    @Test func listEventsUsesParsedRangeAndCalendarFilters() async throws {
        let fake = FakeCalendarStore()
        fake.events = [
            CalendarEvent(
                id: "1",
                title: "Planning",
                startDate: makeDate(year: 2026, month: 5, day: 18, hour: 10),
                endDate: makeDate(year: 2026, month: 5, day: 18, hour: 11),
                isAllDay: false,
                calendarTitle: "Work"
            )
        ]
        let executor = CalendarToolExecutor(calendarStore: fake, memoryStore: MemoryStore(rootURL: try makeTempDirectory()))

        let output = await executor.execute(
            name: "list_events",
            input: .object([
                "from": .string("2026-05-18"),
                "to": .string("2026-05-18"),
                "calendars": .array([.string("Work")]),
            ])
        )

        #expect(output.contains("Planning"))
        #expect(fake.lastQuery?.calendarTitles == ["Work"])
    }

    @Test func createEventValidatesDraft() async throws {
        let fake = FakeCalendarStore()
        let executor = CalendarToolExecutor(calendarStore: fake, memoryStore: MemoryStore(rootURL: try makeTempDirectory()))

        let output = await executor.execute(
            name: "create_event",
            input: .object([
                "title": .string(""),
                "start": .string("2026-05-18T10:00:00Z"),
                "end": .string("2026-05-18T11:00:00Z"),
            ])
        )

        #expect(output.contains("Error:"))
        #expect(fake.createdDrafts.isEmpty)
    }

    @Test func createEventUsesConfiguredDefaultCalendarWhenToolOmitsCalendar() async throws {
        let fake = FakeCalendarStore()
        let executor = CalendarToolExecutor(
            calendarStore: fake,
            memoryStore: MemoryStore(rootURL: try makeTempDirectory()),
            defaultCalendarTitle: "Family"
        )

        _ = await executor.execute(
            name: "create_event",
            input: .object([
                "title": .string("Dinner"),
                "start": .string("2026-05-18T10:00:00Z"),
                "end": .string("2026-05-18T11:00:00Z"),
            ])
        )

        #expect(fake.createdDrafts.first?.calendarTitle == "Family")
    }

    @Test func writeMemoryWritesConfiguredFile() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let executor = CalendarToolExecutor(calendarStore: FakeCalendarStore(), memoryStore: MemoryStore(rootURL: root))

        _ = await executor.execute(name: "write_memory", input: .object(["content": .string("rules: []")]))

        #expect((try String(contentsOf: root.appendingPathComponent("memory.yaml"))).contains("rules"))
    }
}
