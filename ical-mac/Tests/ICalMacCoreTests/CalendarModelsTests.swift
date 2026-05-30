import Foundation
import Testing
@testable import ICalMacCore

struct CalendarModelsTests {
    @Test func invitationResponseStatusMapsEventKitParticipantStatuses() {
        #expect(CalendarInvitationResponseStatus(participantStatus: .pending) == .needsAction)
        #expect(CalendarInvitationResponseStatus(participantStatus: .accepted) == .accepted)
        #expect(CalendarInvitationResponseStatus(participantStatus: .declined) == .declined)
        #expect(CalendarInvitationResponseStatus(participantStatus: .tentative) == .tentative)
    }

    @Test func invitationInfoDecodesLegacySnapshotsWithoutResponseStatus() throws {
        let data = """
        {
          "currentUserStatus": "pending",
          "organizerName": "Alice",
          "currentUserName": "Me",
          "attendeeCount": 3
        }
        """.data(using: .utf8)!

        let invitation = try JSONDecoder().decode(CalendarInvitationInfo.self, from: data)

        #expect(invitation.currentUserStatus == .pending)
        #expect(invitation.responseStatus == .needsAction)
        #expect(invitation.needsResponse)
    }

    @Test func calendarEventDecodesLegacySnapshotsWithoutRecurringFlag() throws {
        let data = """
        {
          "id": "event-1",
          "title": "Standup",
          "startDate": "2026-05-18T10:00:00Z",
          "endDate": "2026-05-18T10:30:00Z",
          "isAllDay": false,
          "calendarTitle": "Work"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(CalendarEvent.self, from: data)

        #expect(event.title == "Standup")
        #expect(!event.isRecurring)
    }

    @Test func calendarEventRoundTripsRecurringFlag() throws {
        let event = CalendarEvent(
            id: "event-1",
            title: "Pay Day",
            startDate: makeDate(year: 2026, month: 5, day: 18, hour: 20),
            endDate: makeDate(year: 2026, month: 5, day: 18, hour: 21),
            isAllDay: false,
            isRecurring: true,
            calendarTitle: "Work"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(CalendarEvent.self, from: try encoder.encode(event))

        #expect(decoded.isRecurring)
    }
}
