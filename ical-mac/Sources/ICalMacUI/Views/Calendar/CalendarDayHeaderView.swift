import SwiftUI

#if DEBUG
#Preview {
    HStack {
        CalendarDayHeaderView(day: Date(), calendar: .current)
            .frame(width: 120, height: 44)
        CalendarDayHeaderView(
            day: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            calendar: .current
        )
        .frame(width: 120, height: 44)
    }
    .padding()
}
#endif

struct CalendarDayHeaderView: View {
    let day: Date
    let calendar: Calendar

    private var isToday: Bool {
        calendar.isDateInToday(day)
    }

    private let headerSpacing: CGFloat = 5
    private let todayCircleSide: CGFloat = 24

    var body: some View {
        HStack(spacing: headerSpacing) {
            Text(Self.weekdayFormatter.string(from: day))
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary)

            if isToday {
                Text(Self.dayFormatter.string(from: day))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: todayCircleSide, height: todayCircleSide)
                    .background(.red, in: Circle())
            } else {
                Text(Self.dayFormatter.string(from: day))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: todayCircleSide, height: todayCircleSide)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
}
