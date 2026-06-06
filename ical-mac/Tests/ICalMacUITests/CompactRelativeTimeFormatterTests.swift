import Foundation
import Testing
@testable import ICalMacUI

struct CompactRelativeTimeFormatterTests {
    private let formatter = CompactRelativeTimeFormatter()
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func formatsRecentTimes() {
        #expect(formatter.string(from: now.addingTimeInterval(-30), relativeTo: now) == "now")
        #expect(formatter.string(from: now.addingTimeInterval(-20 * 60), relativeTo: now) == "20m")
        #expect(formatter.string(from: now.addingTimeInterval(-4 * 3_600), relativeTo: now) == "4h")
    }

    @Test func formatsOlderTimes() {
        #expect(formatter.string(from: now.addingTimeInterval(-2 * 86_400), relativeTo: now) == "2d")
        #expect(formatter.string(from: now.addingTimeInterval(-8 * 86_400), relativeTo: now) == "1w")
        #expect(formatter.string(from: now.addingTimeInterval(-45 * 86_400), relativeTo: now) == "1mo")
        #expect(formatter.string(from: now.addingTimeInterval(-400 * 86_400), relativeTo: now) == "1y")
    }

    @Test func futureDatesClampToNow() {
        #expect(formatter.string(from: now.addingTimeInterval(60), relativeTo: now) == "now")
    }
}
