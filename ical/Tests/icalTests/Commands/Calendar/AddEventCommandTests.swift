import Testing
@testable import ical

@MainActor
struct AddEventCommandTests {

    let base = makeDate(year: 2026, month: 4, day: 24, hour: 10, minute: 0)

    private func cmd(_ args: [String]) throws -> AddEventCommand {
        try AddEventCommand.parse(args)
    }

    @Test func addEvent_shortDurationFlag_ends15MinutesAfterStart() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00", "--short"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(15 * 60))
    }

    @Test func addEvent_longDurationFlag_ends45MinutesAfterStart() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00", "--long"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(45 * 60))
    }

    @Test func addEvent_normalDurationFlag_ends30MinutesAfterStart() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00", "--normal"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(30 * 60))
    }

    @Test func addEvent_withNoDurationFlag_defaultsTo30Minutes() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(30 * 60))
    }

    @Test func addEvent_withExplicitEndTime_usesProvidedEndWhenNoDurationFlag() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00",
                         "--end", "2026-04-24T11:30:00"])
        let end = try c.resolveEndDate(from: base)
        let expected = makeDate(year: 2026, month: 4, day: 24, hour: 11, minute: 30)
        #expect(end == expected)
    }

    @Test func addEvent_durationFlagOverridesExplicitEndTime() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00",
                         "--end", "2026-04-24T12:00:00", "--short"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(15 * 60))
    }

    @Test func addEvent_allDayFlag_marksEventAsAllDay() throws {
        let c = try cmd(["Conference", "--start", "2026-04-24", "--all-day"])
        #expect(c.allDay == true)
    }

    @Test func addEvent_locationAndNotes_capturedInCommand() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00",
                         "--location", "Room 101", "--notes", "Bring slides"])
        #expect(c.location == "Room 101")
        #expect(c.notes == "Bring slides")
    }

    @Test func addEvent_calendarAndAccount_parsedForCalendarDisambiguation() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00",
                         "--calendar", "Work", "--account", "iCloud"])
        #expect(c.calendar == "Work")
        #expect(c.account == "iCloud")
    }
}
