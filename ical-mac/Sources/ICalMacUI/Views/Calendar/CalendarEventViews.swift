import ICalMacCore
import SwiftUI

#if DEBUG
#Preview("Event Chip") {
    CalendarEventChip(event: PreviewData.events[0], color: .purple)
        .frame(width: 180, height: 28)
        .padding()
}

#Preview("Event Block") {
    CalendarEventBlock(event: PreviewData.events[0], color: .purple)
        .frame(width: 180, height: 64)
        .padding()
}
#endif

struct CalendarEventChip: View {
    let event: CalendarEvent
    let color: Color
    @Environment(\.readingTextMetrics) private var textMetrics

    private var horizontalPadding: CGFloat { textMetrics.layoutValue(6) }
    private var verticalPadding: CGFloat { textMetrics.layoutValue(3) }
    private var cornerRadius: CGFloat { textMetrics.layoutValue(5) }

    var body: some View {
        Text(event.title)
            .font(textMetrics.font(.caption, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct CalendarEventBlock: View {
    let event: CalendarEvent
    let color: Color
    @Environment(\.readingTextMetrics) private var textMetrics

    private var railWidth: CGFloat { textMetrics.layoutValue(4) }
    private var contentLeadingPadding: CGFloat { textMetrics.layoutValue(7) }
    private var contentTrailingPadding: CGFloat { textMetrics.layoutValue(5) }
    private var compactVerticalPadding: CGFloat { textMetrics.layoutValue(1) }
    private var regularVerticalPadding: CGFloat { textMetrics.layoutValue(4) }
    private var contentSpacing: CGFloat { 0 }
    private var cornerRadius: CGFloat { textMetrics.layoutValue(5) }
    private var locationLineHeight: CGFloat { textMetrics.layoutValue(30) }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let showsLocation = height >= locationLineHeight
            let verticalPadding = showsLocation ? regularVerticalPadding : compactVerticalPadding

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color.opacity(0.16))

                Rectangle()
                    .fill(color)
                    .frame(width: railWidth)

                VStack(alignment: .leading, spacing: contentSpacing) {
                    Text(event.title)
                        .font(textMetrics.font(.caption, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if showsLocation, let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(textMetrics.font(.caption2))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .foregroundStyle(color)
                .padding(.leading, railWidth + contentLeadingPadding)
                .padding(.trailing, contentTrailingPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .help(event.title)
    }
}
