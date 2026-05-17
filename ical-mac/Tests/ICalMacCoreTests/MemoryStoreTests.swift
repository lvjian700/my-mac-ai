import Foundation
import Testing
@testable import ICalMacCore

struct MemoryStoreTests {
    @Test func memoryReadWriteUsesConfiguredRoot() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryStore(rootURL: root)

        try store.writeMemory("rules:\n  - lunch stays free\n")

        #expect(store.readMemory().contains("lunch stays free"))
        #expect(store.memoryURL.path.hasPrefix(root.path))
    }

    @Test func snapshotRoundTrips() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryStore(rootURL: root)
        let start = makeDate(year: 2026, month: 5, day: 18, hour: 9)
        let end = makeDate(year: 2026, month: 5, day: 18, hour: 10)
        let snapshot = SessionSnapshot(
            events: [
                CalendarEvent(id: "1", title: "Standup", startDate: start, endDate: end, isAllDay: false, calendarTitle: "Work")
            ],
            syncedAt: start,
            range: CalendarQuery(startDate: start, endDate: end)
        )

        try store.writeSnapshot(snapshot)

        #expect(store.readSnapshot() == snapshot)
    }
}
