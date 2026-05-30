import ICalMacCore
import SwiftUI

struct CalendarInvitationStatusPresentation: Equatable {
    var label: String
    var tone: CalendarInvitationStatusTone
    var isDeclined: Bool
    var usesGrayTitle: Bool
    var usesStripedBackground: Bool

    static func make(for responseStatus: CalendarInvitationResponseStatus) -> CalendarInvitationStatusPresentation? {
        switch responseStatus {
        case .needsAction:
            CalendarInvitationStatusPresentation(
                label: "Pending",
                tone: .pending,
                isDeclined: false,
                usesGrayTitle: true,
                usesStripedBackground: true
            )
        case .accepted:
            CalendarInvitationStatusPresentation(
                label: "Accepted",
                tone: .accepted,
                isDeclined: false,
                usesGrayTitle: false,
                usesStripedBackground: false
            )
        case .declined:
            CalendarInvitationStatusPresentation(
                label: "Declined",
                tone: .declined,
                isDeclined: true,
                usesGrayTitle: true,
                usesStripedBackground: false
            )
        case .tentative:
            CalendarInvitationStatusPresentation(
                label: "Tentative",
                tone: .tentative,
                isDeclined: false,
                usesGrayTitle: false,
                usesStripedBackground: true
            )
        case .unknown, .delegated, .completed, .inProcess:
            nil
        }
    }
}

enum CalendarInvitationStatusTone: Equatable {
    case pending
    case accepted
    case declined
    case tentative
}

extension CalendarInvitationStatusTone {
    func fillColor(for eventColor: Color) -> Color {
        switch self {
        case .pending:
            .secondary.opacity(0.18)
        case .accepted:
            eventColor.opacity(0.16)
        case .declined:
            .secondary.opacity(0.1)
        case .tentative:
            eventColor.opacity(0.16)
        }
    }
}
