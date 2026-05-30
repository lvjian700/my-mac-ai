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
}
