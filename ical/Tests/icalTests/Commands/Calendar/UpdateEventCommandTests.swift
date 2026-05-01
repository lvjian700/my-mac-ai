import Testing
@testable import ical

@MainActor
struct UpdateEventCommandTests {

    let base    = makeDate(year: 2026, month: 4, day: 24, hour: 10, minute: 0)
    let baseEnd = makeDate(year: 2026, month: 4, day: 24, hour: 11, minute: 0)

    private func cmd(_ args: [String]) throws -> UpdateEventCommand {
        try UpdateEventCommand.parse(args)
    }

    @Test func noOptions_parsesWithAllNilFields() throws {
        let c = try cmd(["fake-id"])
        #expect(c.title    == nil)
        #expect(c.start    == nil)
        #expect(c.end      == nil)
        #expect(c.short    == false)
        #expect(c.normal   == false)
        #expect(c.long     == false)
        #expect(c.calendar == nil)
        #expect(c.account  == nil)
    }

    @Test func shortFlag_15min() throws {
        let c = try cmd(["fake-id", "--start", "2026-04-24T10:00:00", "--short"])
        let end = try c.resolveEndDate(effectiveStart: base, existingStart: base, existingEnd: baseEnd)
        #expect(end == base.addingTimeInterval(15 * 60))
    }

    @Test func longFlag_45min() throws {
        let c = try cmd(["fake-id", "--start", "2026-04-24T10:00:00", "--long"])
        let end = try c.resolveEndDate(effectiveStart: base, existingStart: base, existingEnd: baseEnd)
        #expect(end == base.addingTimeInterval(45 * 60))
    }

    @Test func normalFlag_30min() throws {
        let c = try cmd(["fake-id", "--start", "2026-04-24T10:00:00", "--normal"])
        let end = try c.resolveEndDate(effectiveStart: base, existingStart: base, existingEnd: baseEnd)
        #expect(end == base.addingTimeInterval(30 * 60))
    }

    @Test func startOnly_preservesOriginalDuration() throws {
        // Move event 2 hours later; 1-hour duration should be preserved
        let newStart = makeDate(year: 2026, month: 4, day: 24, hour: 12, minute: 0)
        let c = try cmd(["fake-id", "--start", "2026-04-24T12:00:00"])
        let end = try c.resolveEndDate(effectiveStart: newStart, existingStart: base, existingEnd: baseEnd)
        let expected = makeDate(year: 2026, month: 4, day: 24, hour: 13, minute: 0)
        #expect(end == expected)
    }

    @Test func explicitEnd_usedWhenNoFlag() throws {
        let c = try cmd(["fake-id", "--end", "2026-04-24T11:30:00"])
        let end = try c.resolveEndDate(effectiveStart: base, existingStart: base, existingEnd: baseEnd)
        let expected = makeDate(year: 2026, month: 4, day: 24, hour: 11, minute: 30)
        #expect(end == expected)
    }

    @Test func shortFlag_overridesExplicitEnd() throws {
        let c = try cmd(["fake-id", "--start", "2026-04-24T10:00:00",
                         "--end", "2026-04-24T12:00:00", "--short"])
        let end = try c.resolveEndDate(effectiveStart: base, existingStart: base, existingEnd: baseEnd)
        #expect(end == base.addingTimeInterval(15 * 60))
    }

    @Test func defaultFormat_isText() throws {
        let c = try cmd(["fake-id", "--title", "New Title"])
        #expect(c.format == .text)
    }

    @Test func jsonFormat_parsed() throws {
        let c = try cmd(["fake-id", "--title", "New Title", "--format", "json"])
        #expect(c.format == .json)
    }

    @Test func eventNotFoundError_hasCorrectMessage() {
        let err = IcalError.eventNotFound(id: "abc-123")
        #expect(err.errorDescription?.contains("abc-123") == true)
        #expect(err.errorDescription?.contains("ical events --format json") == true)
    }

    @Test func noFlags_noStart_returnsNil() throws {
        let c = try cmd(["fake-id"])
        let end = try c.resolveEndDate(effectiveStart: base, existingStart: base, existingEnd: baseEnd)
        #expect(end == nil)
    }

    @Test func calendarOnly_isRecognisedAsChange() throws {
        let c = try cmd(["fake-id", "--calendar", "Work"])
        #expect(c.calendar == "Work")
        // title/start/end/flags are all nil/false, but calendar alone should trigger a change
        #expect(c.title == nil)
        #expect(c.start == nil)
        #expect(c.short == false)
    }
}
