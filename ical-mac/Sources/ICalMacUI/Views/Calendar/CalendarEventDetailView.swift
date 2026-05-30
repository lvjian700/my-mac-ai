import ICalMacCore
import SwiftUI

#if DEBUG
#Preview("Default") {
    CalendarEventDetailView(event: PreviewData.events[0])
        .padding()
        .frame(width: 420, height: 320)
}

#Preview("RSVP Status Details") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(PreviewData.rsvpEvents) { event in
                CalendarEventDetailView(event: event)
            }
        }
        .padding()
    }
    .frame(width: 420, height: 640)
}

#Preview("Multiline Title and Location") {
    CalendarEventDetailView(
        event: CalendarEvent(
            id: "preview-multiline-detail",
            title: "Uber to airport with a very long pickup reminder",
            startDate: PreviewData.now,
            endDate: PreviewData.now.addingTimeInterval(3600),
            isAllDay: false,
            calendarTitle: "Personal",
            location: "Melbourne Airport, Terminal 1 (Qantas Domestic Terminal)",
            notes: "Leave enough time for traffic and airport check-in."
        )
    )
    .padding()
    .frame(width: 420, height: 360)
}
#endif

struct CalendarEventDetailView: View {
    let event: CalendarEvent

    private var formattedTime: String {
        CalendarEventDetailFormatter().dateTimeText(for: event)
    }

    private var locationText: String {
        displayText(event.location, placeholder: "Add Location or Video Call")
    }

    private var notesText: String {
        displayText(event.notes, placeholder: "Add Notes, URL, or Attachments")
    }

    private var hasLocation: Bool {
        hasText(event.location)
    }

    private var hasNotes: Bool {
        hasText(event.notes)
    }

    private var invitationStatus: CalendarInvitationStatusPresentation? {
        event.invitation.flatMap { CalendarInvitationStatusPresentation.make(for: $0.responseStatus) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleAndLocationSegment

            CalendarEventDetailSegment(text: formattedTime, isPlaceholder: false)

            if let invitationStatus {
                CalendarEventInvitationSegment(
                    presentation: invitationStatus,
                    organizerName: event.invitation?.organizerName
                )
            } else {
                CalendarEventDetailSegment(text: "Add Invitees", isPlaceholder: true)
            }

            CalendarEventDetailSegment(text: notesText, isPlaceholder: !hasNotes, lineLimit: hasNotes ? nil : 1)
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
    }

    private var titleAndLocationSegment: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(event.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)

            Divider()
                .padding(.horizontal, 14)

            HStack(alignment: .top, spacing: 12) {
                Text(locationText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(hasLocation ? .primary : .tertiary)
                    .lineLimit(hasLocation ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                CalendarEventDetailAccessory(systemImage: "video.fill")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
        }
        .background(CalendarEventDetailStyle.segmentFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func displayText(_ text: String?, placeholder: String) -> String {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return placeholder
        }
        return text
    }

    private func hasText(_ text: String?) -> Bool {
        guard let text else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct CalendarEventDetailAccessory: View {
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            if systemImage == "video.fill" {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
            }

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.secondary)
        .frame(width: systemImage == "video.fill" ? 50 : 36, height: 28)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct CalendarEventDetailSegment: View {
    let text: String
    let isPlaceholder: Bool
    var lineLimit: Int? = 1

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(isPlaceholder ? .tertiary : .primary)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(CalendarEventDetailStyle.segmentFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CalendarEventInvitationSegment: View {
    let presentation: CalendarInvitationStatusPresentation
    let organizerName: String?

    private var detailText: String {
        if let organizerName, !organizerName.isEmpty {
            return "\(presentation.label) invite from \(organizerName)"
        }
        return "\(presentation.label) invite"
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(detailText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(presentation.isDeclined ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(CalendarEventDetailStyle.segmentFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(detailText)
    }
}

enum CalendarEventDetailStyle {
    static let segmentFill = Color.secondary.opacity(0.07)
}
