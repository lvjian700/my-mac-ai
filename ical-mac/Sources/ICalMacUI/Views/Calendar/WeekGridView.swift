import ICalMacCore
import SwiftUI

#if DEBUG
#Preview {
    WeekGridView()
        .environmentObject(AppModel.preview())
        .frame(width: 900, height: 620)
}
#endif

struct WeekGridView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedDetailEvent: CalendarEvent?

    private let calendar = Calendar.current

    private var hourHeight: CGFloat { 60 }
    private var timeColumnWidth: CGFloat { 72 }
    private var minimumDayWidth: CGFloat { 96 }
    private var dayHeaderHeight: CGFloat { 44 }
    private var dayHeaderVerticalPadding: CGFloat { 0 }
    private var trailingPadding: CGFloat { 6 }
    private var allDayEventHeight: CGFloat { 28 }
    private var allDayEventSpacing: CGFloat { 4 }
    private var allDayEventHorizontalPadding: CGFloat { 3 }
    private var allDayEventVerticalPadding: CGFloat { 5 }
    private var minimumAllDayRowHeight: CGFloat { 40 }
    private var allDaySeparatorHeight: CGFloat { 2 }
    private var hourLabelOffset: CGFloat { 7 }
    private var eventHorizontalInset: CGFloat { 1 }
    private var timedEventLaneGap: CGFloat { 2 }
    private var currentTimeLabelHeight: CGFloat { 20 }
    private var currentTimeDotSide: CGFloat { 9 }
    private var currentTimeLineHeight: CGFloat { 2 }
    private var calendarBottomScrollPadding: CGFloat { 12 }
    private var dayColumnCount: CGFloat { CGFloat(days.count) }

    private var days: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: model.displayedWeekStartDate)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = calendarLayout(for: geometry.size.width)

            VStack(spacing: 0) {
                dayHeader(dayWidth: layout.dayWidth)
                    .frame(width: layout.contentWidth)
                Divider()
                allDayRow(dayWidth: layout.dayWidth)
                    .frame(width: layout.contentWidth)
                Rectangle()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(width: layout.contentWidth, height: allDaySeparatorHeight)
                timeline(dayWidth: layout.dayWidth, contentWidth: layout.contentWidth)
            }
            .frame(width: layout.contentWidth, height: geometry.size.height, alignment: .topLeading)
        }
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }

    private func calendarLayout(for viewportWidth: CGFloat) -> (dayWidth: CGFloat, contentWidth: CGFloat) {
        let availableDayAreaWidth = max(viewportWidth - timeColumnWidth, 0)
        let responsiveDayWidth = availableDayAreaWidth / max(dayColumnCount, 1)
        let dayWidth = max(responsiveDayWidth, minimumDayWidth)
        let contentWidth = timeColumnWidth + dayWidth * dayColumnCount + trailingPadding

        return (dayWidth, contentWidth)
    }

    private func dayHeader(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth, height: 1)

            ForEach(days, id: \.self) { day in
                CalendarDayHeaderView(day: day, calendar: calendar)
                    .frame(width: dayWidth)
                    .padding(.vertical, dayHeaderVerticalPadding)
            }
        }
        .frame(height: dayHeaderHeight)
        .padding(.trailing, trailingPadding)
    }

    private func allDayRow(dayWidth: CGFloat) -> some View {
        let rowHeight = allDayRowHeight()

        return HStack(alignment: .top, spacing: 0) {
            Text("all-day")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, height: rowHeight, alignment: .trailing)
                .padding(.trailing, trailingPadding)

            ForEach(days, id: \.self) { day in
                let events = allDayEvents(for: day)

                VStack(alignment: .leading, spacing: allDayEventSpacing) {
                    ForEach(events, id: \.weekOccurrenceID) { event in
                        CalendarEventChip(event: event)
                            .eventDetailInteraction(
                                event: event,
                                selectedEvent: detailEventBinding(for: event),
                                showDetails: { showEventDetails(event) }
                        )
                    }
                }
                .frame(
                    width: dayWidth,
                    height: max(rowHeight - allDayEventVerticalPadding * 2, allDayEventHeight),
                    alignment: .topLeading
                )
                .padding(.horizontal, allDayEventHorizontalPadding)
                .padding(.vertical, allDayEventVerticalPadding)
            }
        }
        .frame(height: rowHeight, alignment: .top)
        .padding(.trailing, trailingPadding)
    }

    private func allDayRowHeight() -> CGFloat {
        let eventCount = days
            .map { allDayEvents(for: $0).count }
            .max() ?? 0
        guard eventCount > 0 else { return minimumAllDayRowHeight }

        let eventStackHeight = CGFloat(eventCount) * allDayEventHeight
            + CGFloat(max(eventCount - 1, 0)) * allDayEventSpacing
        return max(minimumAllDayRowHeight, eventStackHeight + allDayEventVerticalPadding * 2)
    }

    private func allDayEvents(for day: Date) -> [CalendarEvent] {
        model.visibleAllDayEvents.filter { $0.intersectsDay(day, calendar: calendar) }
    }

    private func timeline(dayWidth: CGFloat, contentWidth: CGFloat) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        ZStack(alignment: .topLeading) {
                            gridLines(dayWidth: dayWidth)
                            eventBlocks(dayWidth: dayWidth)
                            currentTimeScrollTarget(now: context.date, contentWidth: contentWidth)
                            currentTimeIndicator(
                                now: context.date,
                                dayWidth: dayWidth,
                                contentWidth: contentWidth
                            )
                        }
                        .frame(width: contentWidth, height: hourHeight * 24)
                        .onAppear {
                            scrollToCurrentTime(scrollProxy, now: context.date)
                        }
                        .onChange(of: currentMinuteID(for: context.date)) { _, _ in
                            scrollToCurrentTime(scrollProxy, now: context.date)
                        }
                        .onChange(of: model.displayedWeekStartDate) { _, _ in
                            scrollToCurrentTime(scrollProxy, now: context.date)
                        }
                    }

                    Color.clear
                        .frame(width: contentWidth, height: calendarBottomScrollPadding)
                }
            }
            .frame(width: contentWidth)
        }
    }

    private func gridLines(dayWidth: CGFloat) -> some View {
        WeekGridLines(
            dayWidth: dayWidth,
            hourHeight: hourHeight,
            timeColumnWidth: timeColumnWidth,
            trailingPadding: trailingPadding,
            eventHorizontalInset: eventHorizontalInset,
            hourLabelOffset: hourLabelOffset,
            dateForHour: dateForHour
        )
    }

    @ViewBuilder
    private func currentTimeScrollTarget(now: Date, contentWidth: CGFloat) -> some View {
        if currentDayIndex(for: now) != nil {
            CurrentTimeScrollTarget(
                contentWidth: contentWidth,
                height: hourHeight * 24,
                yPosition: currentTimeYPosition(for: now),
                id: Self.currentTimeScrollTargetID
            )
        }
    }

    @ViewBuilder
    private func currentTimeIndicator(now: Date, dayWidth: CGFloat, contentWidth: CGFloat) -> some View {
        if let dayIndex = currentDayIndex(for: now) {
            CurrentTimeIndicator(
                now: now,
                dayIndex: dayIndex,
                dayWidth: dayWidth,
                contentWidth: contentWidth,
                timeColumnWidth: timeColumnWidth,
                trailingPadding: trailingPadding,
                hourHeight: hourHeight,
                labelHeight: currentTimeLabelHeight,
                dotSide: currentTimeDotSide,
                lineHeight: currentTimeLineHeight,
                yPosition: currentTimeYPosition(for: now)
            )
        }
    }

    private func eventBlocks(dayWidth: CGFloat) -> some View {
        let frames = TimedEventWeekLayout.frames(
            for: model.visibleTimedEvents,
            weekStartDate: model.displayedWeekStartDate,
            calendar: calendar,
            dayWidth: dayWidth,
            timeColumnWidth: timeColumnWidth,
            hourHeight: hourHeight,
            eventHorizontalInset: eventHorizontalInset,
            laneGap: timedEventLaneGap
        )

        return ForEach(frames) { frame in
            CalendarEventBlock(event: frame.event)
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                .eventDetailInteraction(
                    event: frame.event,
                    selectedEvent: detailEventBinding(for: frame.event),
                    showDetails: { showEventDetails(frame.event) }
                )
                .offset(x: frame.x, y: frame.y)
        }
    }

    private func showEventDetails(_ event: CalendarEvent) {
        selectedDetailEvent = event
    }

    private func detailEventBinding(for event: CalendarEvent) -> Binding<CalendarEvent?> {
        Binding {
            selectedDetailEvent?.id == event.id ? selectedDetailEvent : nil
        } set: { nextEvent in
            if let nextEvent {
                selectedDetailEvent = nextEvent
            } else if selectedDetailEvent?.id == event.id {
                selectedDetailEvent = nil
            }
        }
    }

    private func scrollToCurrentTime(_ proxy: ScrollViewProxy, now: Date) {
        guard currentDayIndex(for: now) != nil else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(Self.currentTimeScrollTargetID, anchor: .center)
            }
        }
    }

    private func currentDayIndex(for date: Date) -> Int? {
        let weekStart = calendar.startOfDay(for: model.displayedWeekStartDate)
        let currentDayStart = calendar.startOfDay(for: date)
        guard let dayIndex = calendar.dateComponents([.day], from: weekStart, to: currentDayStart).day,
              dayIndex >= 0,
              dayIndex < 7 else {
            return nil
        }
        return dayIndex
    }

    private func currentTimeYPosition(for date: Date) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = CGFloat((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
        return seconds / 3600 * hourHeight
    }

    private func currentMinuteID(for date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate / 60)
    }

    private func dateForHour(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: model.displayedWeekStartDate) ?? model.displayedWeekStartDate
    }

    private static let currentTimeScrollTargetID = "current-time-scroll-target"
}
