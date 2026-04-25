import Testing
@testable import ical

@MainActor
struct AddEventCommandTests {

    let base = makeDate(year: 2026, month: 4, day: 24, hour: 10, minute: 0)

    private func cmd(_ args: [String]) throws -> AddEventCommand {
        try AddEventCommand.parse(args)
    }

    @Test func shortFlag_15minutes() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00", "--short"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(15 * 60))
    }

    @Test func longFlag_45minutes() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00", "--long"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(45 * 60))
    }

    @Test func normalFlag_30minutes() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00", "--normal"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(30 * 60))
    }

    @Test func noFlag_defaults30minutes() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(30 * 60))
    }

    @Test func explicitEnd_usedWhenNoFlag() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00",
                         "--end", "2026-04-24T11:30:00"])
        let end = try c.resolveEndDate(from: base)
        let expected = makeDate(year: 2026, month: 4, day: 24, hour: 11, minute: 30)
        #expect(end == expected)
    }

    @Test func shortFlag_overridesExplicitEnd() throws {
        let c = try cmd(["Meeting", "--start", "2026-04-24T10:00:00",
                         "--end", "2026-04-24T12:00:00", "--short"])
        let end = try c.resolveEndDate(from: base)
        #expect(end == base.addingTimeInterval(15 * 60))
    }
}
