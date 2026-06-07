import ICalMacCore
import SwiftUI

#if DEBUG
#Preview("Event Chip") {
    CalendarEventChip(event: PreviewData.events[0])
        .frame(width: 180, height: 28)
        .padding()
}

#Preview("RSVP Event Chips") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(PreviewData.rsvpEvents) { event in
            CalendarEventChip(event: event)
                .frame(width: 240, height: 28)
        }
    }
    .padding()
}

#Preview("Category Event Chips") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(PreviewData.categoryEvents) { event in
            CalendarEventChip(event: event)
                .frame(width: 260, height: 28)
        }
    }
    .padding()
}

#Preview("Recurring Event Chips") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(PreviewData.recurringEventSamples) { event in
            CalendarEventChip(event: event)
                .frame(width: 260, height: 28)
        }
    }
    .padding()
}

#Preview("Event Block") {
    CalendarEventBlock(event: PreviewData.events[0])
        .frame(width: 180, height: 64)
        .padding()
}

#Preview("RSVP Event Blocks") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(PreviewData.rsvpEvents) { event in
            CalendarEventBlock(event: event)
                .frame(width: 240, height: 44)
        }
    }
    .padding()
}

#Preview("Recurring Event Blocks") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(PreviewData.recurringEventSamples) { event in
            CalendarEventBlock(event: event)
                .frame(width: 260, height: 44)
        }
    }
    .padding()
}

#Preview("Category Event Blocks") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(PreviewData.categoryEvents) { event in
            CalendarEventBlock(event: event)
                .frame(width: 260, height: 44)
        }
    }
    .padding()
}
#endif

struct CalendarEventChip: View {
    let event: CalendarEvent

    private var horizontalPadding: CGFloat { 6 }
    private var verticalPadding: CGFloat { 3 }
    private var cornerRadius: CGFloat { 5 }
    private var categoryPresentation: CalendarEventCategoryPresentation {
        CalendarEventCategoryPresentation.make(for: event)
    }
    private var statusPresentation: CalendarInvitationStatusPresentation? {
        event.invitation.flatMap { CalendarInvitationStatusPresentation.make(for: $0.responseStatus) }
    }
    private var eventColor: Color { categoryPresentation.color }

    var body: some View {
        CalendarEventTitleLabel(
            title: event.title,
            symbolName: categoryPresentation.symbolName,
            font: .caption.weight(.medium),
            iconWidth: 12,
            spacing: 3,
            lineLimit: 1,
            showsRecurrenceIcon: event.isRecurring,
            isDeclined: statusPresentation?.isDeclined == true
        )
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(statusPresentation?.usesGrayTitle == true ? .secondary : eventColor)
            .background {
                CalendarEventStatusBackground(
                    eventColor: eventColor,
                    presentation: statusPresentation,
                    baseOpacity: categoryPresentation.fillOpacity * 0.875
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .opacity(statusPresentation?.isDeclined == true ? 0.72 : 1)
            .help(helpText)
    }

    private var helpText: String {
        var details = [categoryPresentation.label]
        if event.isRecurring {
            details.append("repeats")
        }
        if let statusPresentation {
            details.append(statusPresentation.label)
        }
        return "\(event.title) - \(details.joined(separator: ", "))"
    }
}

struct CalendarEventBlock: View {
    let event: CalendarEvent

    private var railWidth: CGFloat { 2 }
    private var contentLeadingPadding: CGFloat { 6 }
    private var contentTrailingPadding: CGFloat { 5 }
    private var regularVerticalPadding: CGFloat { 4 }
    private var cornerRadius: CGFloat { 5 }
    private var categoryPresentation: CalendarEventCategoryPresentation {
        CalendarEventCategoryPresentation.make(for: event)
    }
    private var statusPresentation: CalendarInvitationStatusPresentation? {
        event.invitation.flatMap { CalendarInvitationStatusPresentation.make(for: $0.responseStatus) }
    }
    private var eventColor: Color { categoryPresentation.color }
    private var titleLeadingPadding: CGFloat {
        categoryPresentation.showsLeadingRail ? railWidth + contentLeadingPadding : contentLeadingPadding
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CalendarEventStatusBackground(
                eventColor: eventColor,
                presentation: statusPresentation,
                baseOpacity: categoryPresentation.fillOpacity
            )

            if categoryPresentation.showsLeadingRail {
                Rectangle()
                    .fill(statusPresentation?.isDeclined == true ? Color.secondary.opacity(0.55) : eventColor)
                    .frame(width: railWidth)
            }

            ViewThatFits(in: .vertical) {
                eventContent(titleLineLimit: 2, showsTimeRange: true)
                eventContent(titleLineLimit: 2, showsTimeRange: false)
                eventContent(titleLineLimit: 1, showsTimeRange: false)
            }
            .foregroundStyle(statusPresentation?.usesGrayTitle == true ? .secondary : eventColor)
            .padding(.leading, titleLeadingPadding)
            .padding(.trailing, contentTrailingPadding)
            .padding(.vertical, regularVerticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
        .opacity(statusPresentation?.isDeclined == true ? 0.72 : 1)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .help(helpText)
    }

    private func eventContent(titleLineLimit: Int, showsTimeRange: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            CalendarEventTitleLabel(
                title: event.title,
                symbolName: categoryPresentation.symbolName,
                font: .caption.weight(.semibold),
                iconWidth: 12,
                spacing: 3,
                lineLimit: titleLineLimit,
                showsRecurrenceIcon: event.isRecurring,
                isDeclined: statusPresentation?.isDeclined == true
            )

            if showsTimeRange {
                Text(timeRangeText)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
        }
    }

    private var timeRangeText: String {
        Self.eventTimeRangeFormatter.string(from: event.startDate, to: event.endDate)
    }

    private var helpText: String {
        var details = [categoryPresentation.label]
        if event.isRecurring {
            details.append("repeats")
        }
        if let statusPresentation {
            details.append(statusPresentation.label)
        }
        return "\(event.title) - \(details.joined(separator: ", "))"
    }

    private static let eventTimeRangeFormatter = CalendarEventTimeRangeFormatter()
}

private struct CalendarEventTitleLabel: View {
    let title: String
    let symbolName: String?
    let font: Font
    let iconWidth: CGFloat
    let spacing: CGFloat
    let lineLimit: Int
    let showsRecurrenceIcon: Bool
    let isDeclined: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(font)
                    .imageScale(.small)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(font)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
                .strikethrough(isDeclined, color: .secondary)
                .layoutPriority(1)

            if showsRecurrenceIcon {
                Spacer(minLength: spacing)

                Image(systemName: "repeat")
                    .font(font)
                    .imageScale(.small)
                    .frame(width: iconWidth)
                    .accessibilityLabel("Repeats")
            }
        }
    }
}

private final class CalendarEventTimeRangeFormatter {
    private let calendar = Calendar.current
    private let hourFormatter: DateFormatter
    private let minuteFormatter: DateFormatter
    private let periodFormatter: DateFormatter

    init() {
        hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "h"

        minuteFormatter = DateFormatter()
        minuteFormatter.dateFormat = "h:mm"

        periodFormatter = DateFormatter()
        periodFormatter.dateFormat = "a"
    }

    func string(from startDate: Date, to endDate: Date) -> String {
        let start = timeText(for: startDate)
        let end = timeText(for: endDate)
        let startPeriod = periodFormatter.string(from: startDate)
        let endPeriod = periodFormatter.string(from: endDate)

        if startPeriod == endPeriod {
            return "\(start)-\(end) \(endPeriod)"
        }

        return "\(start) \(startPeriod)-\(end) \(endPeriod)"
    }

    private func timeText(for date: Date) -> String {
        let minute = calendar.component(.minute, from: date)
        return (minute == 0 ? hourFormatter : minuteFormatter).string(from: date)
    }
}

private struct CalendarEventStatusBackground: View {
    let eventColor: Color
    let presentation: CalendarInvitationStatusPresentation?
    let baseOpacity: Double

    var body: some View {
        if let presentation, presentation.usesStripedBackground {
            DiagonalStripeBackground(
                baseColor: .white,
                stripeColor: presentation.tone.fillColor(for: eventColor)
            )
        } else if let presentation {
            presentation.tone.fillColor(for: eventColor)
        } else {
            eventColor.opacity(baseOpacity)
        }
    }
}

private struct DiagonalStripeBackground: View {
    let baseColor: Color
    let stripeColor: Color

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(baseColor)
            )

            let stripeWidth: CGFloat = 5
            let stripeSpacing: CGFloat = 12
            var stripes = Path()

            for x in stride(from: -size.height, through: size.width + size.height, by: stripeSpacing) {
                stripes.move(to: CGPoint(x: x, y: size.height))
                stripes.addLine(to: CGPoint(x: x + stripeWidth, y: size.height))
                stripes.addLine(to: CGPoint(x: x + size.height + stripeWidth, y: 0))
                stripes.addLine(to: CGPoint(x: x + size.height, y: 0))
                stripes.closeSubpath()
            }

            context.fill(stripes, with: .color(stripeColor))
        }
    }
}
