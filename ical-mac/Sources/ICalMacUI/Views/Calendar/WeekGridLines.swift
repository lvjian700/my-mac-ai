import SwiftUI

#if DEBUG
#Preview {
    WeekGridLines(
        dayWidth: 100,
        hourHeight: 58,
        timeColumnWidth: 72,
        trailingPadding: 8,
        eventHorizontalInset: 4,
        hourLabelOffset: 7,
        dateForHour: { hour in
            Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        }
    )
    .frame(width: 772, height: 58 * 24)
    .padding()
}
#endif

struct WeekGridLines: View {
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat
    let trailingPadding: CGFloat
    let eventHorizontalInset: CGFloat
    let hourLabelOffset: CGFloat
    let dateForHour: (Int) -> Date
    @Environment(\.readingTextMetrics) private var textMetrics

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(Color.secondary.opacity(hour == 0 ? 0.25 : 0.12))
                    .frame(height: 1)
                    .offset(x: timeColumnWidth, y: CGFloat(hour) * hourHeight)

                if hour < 24 {
                    Text(Self.hourFormatter.string(from: dateForHour(hour)))
                        .font(textMetrics.font(.caption))
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth - trailingPadding, alignment: .trailing)
                        .offset(y: hour == 0 ? eventHorizontalInset : CGFloat(hour) * hourHeight - hourLabelOffset)
                }
            }

            ForEach(0...7, id: \.self) { day in
                Rectangle()
                    .fill(Color.secondary.opacity(0.10))
                    .frame(width: 1, height: hourHeight * 24)
                    .offset(x: timeColumnWidth + CGFloat(day) * dayWidth)
            }
        }
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }()
}
