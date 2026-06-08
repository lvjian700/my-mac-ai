@testable import ICalMac
import Testing

struct CalendarInvitationStatusPresentationTests {
    @Test func mapsRsvpStatusesToCalendarLabels() {
        #expect(CalendarInvitationStatusPresentation.make(for: .needsAction)?.label == "Pending")
        #expect(CalendarInvitationStatusPresentation.make(for: .accepted)?.label == "Accepted")
        #expect(CalendarInvitationStatusPresentation.make(for: .declined)?.label == "Declined")
        #expect(CalendarInvitationStatusPresentation.make(for: .tentative)?.label == "Tentative")
    }

    @Test func hidesNonRsvpStatusesFromCalendarChrome() {
        #expect(CalendarInvitationStatusPresentation.make(for: .unknown) == nil)
        #expect(CalendarInvitationStatusPresentation.make(for: .delegated) == nil)
        #expect(CalendarInvitationStatusPresentation.make(for: .completed) == nil)
        #expect(CalendarInvitationStatusPresentation.make(for: .inProcess) == nil)
    }
}
