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
    @Environment(\.readingTextMetrics) private var textMetrics

    private var headerBottomPadding: CGFloat { textMetrics.layoutValue(12) }

    var body: some View {
        VStack(spacing: 0) {
            WeekHeaderView()
                .padding(.horizontal)
                .padding(.bottom, headerBottomPadding)

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
        }
    }
}

private struct CalendarUnavailableView: View {
    let title: String
    let systemImage: String
    let detail: String
    @Environment(\.readingTextMetrics) private var textMetrics

    private var topSpacer: CGFloat { textMetrics.layoutValue(80) }

    var body: some View {
        VStack {
            Spacer(minLength: topSpacer)

            ContentUnavailableView {
                Label(title, systemImage: systemImage)
                    .font(textMetrics.font(.title3, weight: .semibold))
            } description: {
                Text(detail)
                    .font(textMetrics.font(.body))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct WeekHeaderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.readingTextMetrics) private var textMetrics

    private var headerSpacing: CGFloat { textMetrics.layoutValue(16) }
    private var minHeight: CGFloat { textMetrics.layoutValue(58) }

    var body: some View {
        HStack(spacing: headerSpacing) {
            Text(Self.monthFormatter.string(from: model.displayedWeekStartDate))
                .font(textMetrics.font(.largeTitle, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            navigationControls
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
    }

    private var navigationControls: some View {
        HStack(spacing: 8) {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            ControlGroup {
                Button {
                    Task { await model.moveDisplayedWeek(by: -1) }
                } label: {
                    Label("Previous Week", systemImage: "chevron.left")
                }

                Button {
                    Task { await model.showToday() }
                } label: {
                    Text("Today")
                }

                Button {
                    Task { await model.moveDisplayedWeek(by: 1) }
                } label: {
                    Label("Next Week", systemImage: "chevron.right")
                }
            }
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
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 260)
    }
}

private struct WeekGridView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.readingTextMetrics) private var textMetrics

    private let calendar = Calendar.current

    private var hourHeight: CGFloat { 58 }
    private var timeColumnWidth: CGFloat { textMetrics.layoutValue(72) }
    private var minimumDayWidth: CGFloat { textMetrics.layoutValue(92) }
    private var dayHeaderHeight: CGFloat { textMetrics.layoutValue(48) }
    private var dayHeaderVerticalPadding: CGFloat { textMetrics.layoutValue(8) }
    private var trailingPadding: CGFloat { 8 }
    private var allDayLabelHeight: CGFloat { textMetrics.layoutValue(42) }
    private var allDayLabelTopPadding: CGFloat { textMetrics.layoutValue(7) }
    private var allDayEventHeight: CGFloat { textMetrics.layoutValue(34) }
    private var allDayEventHorizontalPadding: CGFloat { 3 }
    private var allDayEventVerticalPadding: CGFloat { 5 }
    private var allDayRowHeight: CGFloat { textMetrics.layoutValue(44) }
    private var hourLabelOffset: CGFloat { textMetrics.layoutValue(7) }
    private var eventHorizontalInset: CGFloat { 4 }
    private var eventVerticalInset: CGFloat { 3 }
    private var minimumEventWidth: CGFloat { 44 }
    private var minimumEventHeight: CGFloat { textMetrics.layoutValue(28) }

    private var days: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: model.displayedWeekStartDate)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let dayWidth = max((geometry.size.width - timeColumnWidth) / 7, minimumDayWidth)
            let contentWidth = timeColumnWidth + dayWidth * 7

            ScrollView(.horizontal) {
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
                .frame(width: contentWidth, height: geometry.size.height, alignment: .topLeading)
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
                .padding(.vertical, dayHeaderVerticalPadding)
            }
        }
        .frame(height: dayHeaderHeight)
        .padding(.trailing, trailingPadding)
    }

    private func allDayRow(dayWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text("all-day")
                .font(textMetrics.font(.caption))
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, height: allDayLabelHeight, alignment: .topTrailing)
                .padding(.trailing, trailingPadding)
                .padding(.top, allDayLabelTopPadding)

            ForEach(days, id: \.self) { day in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.visibleAllDayEvents.filter { $0.intersectsDay(day, calendar: calendar) }) { event in
                        EventChip(event: event, color: Color(calendarHex: model.colorHex(for: event)) ?? .accentColor)
                    }
                }
                .frame(width: dayWidth, height: allDayEventHeight, alignment: .topLeading)
                .padding(.horizontal, allDayEventHorizontalPadding)
                .padding(.vertical, allDayEventVerticalPadding)
            }
        }
        .frame(height: allDayRowHeight, alignment: .top)
        .padding(.trailing, trailingPadding)
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

    private func eventBlocks(dayWidth: CGFloat) -> some View {
        ForEach(model.visibleTimedEvents) { event in
            if let frame = frame(for: event, dayWidth: dayWidth) {
                EventBlock(event: event, color: Color(calendarHex: model.colorHex(for: event)) ?? .accentColor)
                    .frame(width: max(dayWidth - trailingPadding, minimumEventWidth), height: frame.height, alignment: .topLeading)
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
            x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + eventHorizontalInset,
            y: CGFloat(startOffset / 3600) * hourHeight + eventVerticalInset,
            height: max(CGFloat(duration / 3600) * hourHeight - eventVerticalInset * 2, minimumEventHeight)
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
    @Environment(\.readingTextMetrics) private var textMetrics

    private var isToday: Bool {
        calendar.isDateInToday(day)
    }

    private var headerSpacing: CGFloat { textMetrics.layoutValue(4) }
    private var todayCircleSide: CGFloat { textMetrics.layoutValue(26) }

    var body: some View {
        VStack(spacing: headerSpacing) {
            Text(Self.weekdayFormatter.string(from: day))
                .font(textMetrics.font(.caption, weight: .medium))
                .foregroundStyle(isToday ? .red : .secondary)

            if isToday {
                Text(Self.dayFormatter.string(from: day))
                    .font(textMetrics.font(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: todayCircleSide, height: todayCircleSide)
                    .background(.red, in: Circle())
            } else {
                Text(Self.dayFormatter.string(from: day))
                    .font(textMetrics.font(.headline))
                    .foregroundStyle(.primary)
                    .frame(width: todayCircleSide, height: todayCircleSide)
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

private struct EventBlock: View {
    let event: CalendarEvent
    let color: Color
    @Environment(\.readingTextMetrics) private var textMetrics

    private var contentSpacing: CGFloat { textMetrics.layoutValue(3) }
    private var contentPadding: CGFloat { textMetrics.layoutValue(6) }
    private var cornerRadius: CGFloat { textMetrics.layoutValue(6) }

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            Text(event.title)
                .font(textMetrics.font(.caption, weight: .semibold))
                .lineLimit(2)
            Text(Self.intervalFormatter.string(from: event.startDate, to: event.endDate))
                .font(textMetrics.font(.caption2))
                .lineLimit(1)
            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(textMetrics.font(.caption2))
                    .lineLimit(1)
            }
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(color)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
