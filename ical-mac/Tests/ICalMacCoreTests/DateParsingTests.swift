import Foundation
import Testing
@testable import ICalMacCore

struct DateParsingTests {
    @Test func queryResolvesDateOnlyEndToEndOfDay() throws {
        let parser = CalendarDateParser(calendar: Calendar(identifier: .gregorian))
        let query = try parser.query(from: "2026-05-18", to: "2026-05-18")
        let endComponents = Calendar(identifier: .gregorian).dateComponents([.hour, .minute, .second], from: query.endDate)

        #expect(endComponents.hour == 23)
        #expect(endComponents.minute == 59)
        #expect(endComponents.second == 59)
    }

    @Test func invalidRangeThrows() {
        let parser = CalendarDateParser(calendar: Calendar(identifier: .gregorian))

        #expect(throws: DateParsingError.invalidRange) {
            _ = try parser.query(from: "2026-05-19", to: "2026-05-18")
        }
    }
}
