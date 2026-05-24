import SwiftUI

#if DEBUG
#Preview {
    ZStack(alignment: .topLeading) {
        CurrentTimeIndicator(
            now: Date(),
            dayIndex: 2,
            dayWidth: 120,
            contentWidth: 912,
            timeColumnWidth: 72,
            trailingPadding: 8,
            hourHeight: 58,
            labelHeight: 28,
            dotSide: 9,
            lineHeight: 2,
            yPosition: 480
        )
    }
    .frame(width: 912, height: 760, alignment: .topLeading)
    .padding()
}
#endif

struct CurrentTimeIndicator: View {
    let now: Date
    let dayIndex: Int
    let dayWidth: CGFloat
    let contentWidth: CGFloat
    let timeColumnWidth: CGFloat
    let trailingPadding: CGFloat
    let hourHeight: CGFloat
    let labelHeight: CGFloat
    let dotSide: CGFloat
    let lineHeight: CGFloat
    let yPosition: CGFloat
    @Environment(\.readingTextMetrics) private var textMetrics

    private var todayX: CGFloat {
        timeColumnWidth + CGFloat(dayIndex) * dayWidth
    }

    private var gridWidth: CGFloat {
        max(contentWidth - timeColumnWidth, 0)
    }

    private var labelY: CGFloat {
        min(max(yPosition - labelHeight / 2, 0), hourHeight * 24 - labelHeight)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.red.opacity(0.16))
                .frame(width: gridWidth, height: 1)
                .offset(x: timeColumnWidth, y: yPosition)

            Rectangle()
                .fill(Color.red)
                .frame(width: dayWidth, height: lineHeight)
                .offset(x: todayX, y: yPosition - lineHeight / 2)

            Circle()
                .fill(Color.red)
                .frame(width: dotSide, height: dotSide)
                .offset(x: todayX - dotSide / 2, y: yPosition - dotSide / 2)

            Text(Self.currentTimeFormatter.string(from: now))
                .font(textMetrics.font(.caption, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, textMetrics.layoutValue(6))
                .frame(height: labelHeight)
                .background(Color.red, in: Capsule())
                .frame(width: timeColumnWidth - trailingPadding, alignment: .trailing)
                .offset(y: labelY)
        }
        .allowsHitTesting(false)
    }

    private static let currentTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()
}

struct CurrentTimeScrollTarget<ID: Hashable>: View {
    let contentWidth: CGFloat
    let height: CGFloat
    let yPosition: CGFloat
    let id: ID

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: yPosition)
            Color.clear
                .frame(width: contentWidth, height: 1)
                .id(id)
            Spacer(minLength: 0)
        }
        .frame(width: contentWidth, height: height, alignment: .top)
        .allowsHitTesting(false)
    }
}
