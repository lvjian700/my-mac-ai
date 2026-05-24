import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    CalendarEventDetailView(event: PreviewData.events[0])
        .padding()
        .frame(width: 420, height: 320)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleAndLocationSegment

            CalendarEventDetailSegment(text: formattedTime, isPlaceholder: false)

            CalendarEventDetailSegment(text: "Add Invitees", isPlaceholder: true)

            CalendarEventDetailSegment(text: notesText, isPlaceholder: !hasNotes)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .frame(height: 40)
            .padding(.horizontal, 14)

            Divider()
                .padding(.horizontal, 14)

            HStack(spacing: 12) {
                Text(locationText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(hasLocation ? .primary : .tertiary)
                    .lineLimit(1)

                Spacer(minLength: 12)

                CalendarEventDetailAccessory(systemImage: "video.fill")
            }
            .frame(height: 40)
            .padding(.horizontal, 14)
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

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(isPlaceholder ? .tertiary : .primary)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(CalendarEventDetailStyle.segmentFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

enum CalendarEventDetailStyle {
    static let segmentFill = Color.secondary.opacity(0.07)
}
