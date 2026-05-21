import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    WeekCalendarView()
        .environmentObject(AppModel.preview())
        .frame(width: 1180, height: 720)
}
#endif

struct WeekCalendarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            WeekHeaderView()
                .padding(.horizontal)
                .padding(.bottom, 12)

            Divider()

            if model.accessStatus == .denied {
                CalendarUnavailableView(
                    title: "Calendar Access Needed",
                    systemImage: "calendar.badge.exclamationmark",
                    detail: model.statusText
                )
            } else {
                WeekGridView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .principal) {
                CalendarModeSegmentedControl(selection: .week)
            }
            ToolbarItem(placement: .primaryAction) {
                Color.clear.frame(width: 28)
            }
        }
    }
}

private struct CalendarUnavailableView: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack {
            Spacer(minLength: 80)

            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(detail)
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct WeekHeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            Text(Self.monthFormatter.string(from: model.displayedWeekStartDate))
                .font(.largeTitle.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            navigationControls
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .center)
    }

    private var navigationControls: some View {
        HStack(spacing: 8) {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task { await model.moveDisplayedWeek(by: -1) }
            } label: {
                Label("Previous Week", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .disabled(model.isRefreshing)

            Button {
                Task { await model.showToday() }
            } label: {
                Text("Today")
            }
            .buttonStyle(.bordered)
            .disabled(model.isRefreshing)

            Button {
                Task { await model.moveDisplayedWeek(by: 1) }
            } label: {
                Label("Next Week", systemImage: "chevron.right")
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .disabled(model.isRefreshing)
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}

private enum CalendarDisplayMode: Hashable, CaseIterable {
    case day
    case week
    case month
    case year

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

private struct CalendarModeSegmentedControl: View {
    @State private var selection: CalendarDisplayMode

    init(selection: CalendarDisplayMode) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        Picker("View Mode", selection: $selection) {
            ForEach(CalendarDisplayMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 260)
    }
}

private struct WeekGridView: View {
    @EnvironmentObject private var model: AppModel

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 58
    private let timeColumnWidth: CGFloat = 72
    private let minimumDayWidth: CGFloat = 92

    private var days: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: model.displayedWeekStartDate)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let dayWidth = max((geometry.size.width - timeColumnWidth) / 7, minimumDayWidth)
            let contentWidth = timeColumnWidth + dayWidth * 7

            VStack(spacing: 0) {
                dayHeader(dayWidth: dayWidth)
                    .frame(width: contentWidth)
                allDayRow(dayWidth: dayWidth)
                    .frame(width: contentWidth)
                Divider()
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        gridLines(dayWidth: dayWidth)
                        eventBlocks(dayWidth: dayWidth)
                    }
                    .frame(width: contentWidth, height: hourHeight * 24)
                }
                .frame(width: contentWidth)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }

    private func dayHeader(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth, height: 1)

            ForEach(days, id: \.self) { day in
                DayColumnHeader(day: day, calendar: calendar)
                .frame(width: dayWidth)
                .padding(.vertical, 8)
            }
        }
        .frame(height: 48)
        .padding(.trailing, 8)
    }

    private func allDayRow(dayWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text("all-day")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, height: 42, alignment: .topTrailing)
                .padding(.trailing, 8)
                .padding(.top, 7)

            ForEach(days, id: \.self) { day in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.visibleAllDayEvents.filter { $0.intersectsDay(day, calendar: calendar) }) { event in
                        EventChip(event: event, color: Color(calendarHex: model.colorHex(for: event)) ?? .accentColor)
                    }
                }
                .frame(width: dayWidth, height: 34, alignment: .topLeading)
                .padding(.horizontal, 3)
                .padding(.vertical, 5)
            }
        }
        .frame(height: 44, alignment: .top)
        .padding(.trailing, 8)
    }

    private func gridLines(dayWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(Color.secondary.opacity(hour == 0 ? 0.25 : 0.12))
                    .frame(height: 1)
                    .offset(x: timeColumnWidth, y: CGFloat(hour) * hourHeight)

                if hour < 24 {
                    Text(Self.hourFormatter.string(from: dateForHour(hour)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth - 8, alignment: .trailing)
                        .offset(y: hour == 0 ? 4 : CGFloat(hour) * hourHeight - 7)
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

    private func eventBlocks(dayWidth: CGFloat) -> some View {
        ForEach(model.visibleTimedEvents) { event in
            if let frame = frame(for: event, dayWidth: dayWidth) {
                EventBlock(event: event, color: Color(calendarHex: model.colorHex(for: event)) ?? .accentColor)
                    .frame(width: max(dayWidth - 8, 44), height: frame.height, alignment: .topLeading)
                    .offset(x: frame.x, y: frame.y)
            }
        }
    }

    private func frame(for event: CalendarEvent, dayWidth: CGFloat) -> (x: CGFloat, y: CGFloat, height: CGFloat)? {
        let eventStart = max(event.startDate, model.displayedWeekRange.startDate)
        let dayStart = calendar.startOfDay(for: eventStart)
        guard let dayIndex = calendar.dateComponents([.day], from: model.displayedWeekStartDate, to: dayStart).day,
              dayIndex >= 0,
              dayIndex < 7 else {
            return nil
        }

        let visibleStart = max(event.startDate, dayStart)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? event.endDate
        let visibleEnd = min(event.endDate, nextDay)
        let startOffset = visibleStart.timeIntervalSince(dayStart)
        let duration = max(visibleEnd.timeIntervalSince(visibleStart), 30 * 60)

        return (
            x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + 4,
            y: CGFloat(startOffset / 3600) * hourHeight + 3,
            height: max(CGFloat(duration / 3600) * hourHeight - 6, 28)
        )
    }

    private func dateForHour(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: model.displayedWeekStartDate) ?? model.displayedWeekStartDate
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }()
}

private struct DayColumnHeader: View {
    let day: Date
    let calendar: Calendar

    private var isToday: Bool {
        calendar.isDateInToday(day)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(Self.weekdayFormatter.string(from: day))
                .font(.caption.weight(.medium))
                .foregroundStyle(isToday ? .red : .secondary)

            if isToday {
                Text(Self.dayFormatter.string(from: day))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(.red, in: Circle())
            } else {
                Text(Self.dayFormatter.string(from: day))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
            }
        }
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

private struct EventChip: View {
    let event: CalendarEvent
    let color: Color

    var body: some View {
        Text(event.title)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct EventBlock: View {
    let event: CalendarEvent
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(event.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Text(Self.intervalFormatter.string(from: event.startDate, to: event.endDate))
                .font(.caption2)
                .lineLimit(1)
            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(color)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(color.opacity(0.55), lineWidth: 1)
        }
        .help(event.title)
    }

    private static let intervalFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension CalendarEvent {
    func intersectsDay(_ day: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return startDate < end && endDate > start
    }
}
