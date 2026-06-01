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
    @Environment(\.readingTextMetrics) private var textMetrics
    @State private var selectedDetailEvent: CalendarEvent?

    private let calendar = Calendar.current

    private var hourHeight: CGFloat { textMetrics.layoutValue(60) }
    private var timeColumnWidth: CGFloat { textMetrics.layoutValue(72) }
    private var minimumDayWidth: CGFloat { textMetrics.layoutValue(96) }
    private var dayHeaderHeight: CGFloat { 44 }
    private var dayHeaderVerticalPadding: CGFloat { 0 }
    private var trailingPadding: CGFloat { 8 }
    private var allDayEventHeight: CGFloat { textMetrics.layoutValue(28) }
    private var allDayEventHorizontalPadding: CGFloat { 3 }
    private var allDayEventVerticalPadding: CGFloat { 5 }
    private var allDayRowHeight: CGFloat { textMetrics.layoutValue(40) }
    private var allDaySeparatorHeight: CGFloat { 2 }
    private var hourLabelOffset: CGFloat { textMetrics.layoutValue(7) }
    private var eventHorizontalInset: CGFloat { 4 }
    private var eventVerticalInset: CGFloat { 1 }
    private var minimumEventWidth: CGFloat { 44 }
    private var minimumEventHeight: CGFloat { textMetrics.layoutValue(28) }
    private var currentTimeLabelHeight: CGFloat { textMetrics.layoutValue(20) }
    private var currentTimeDotSide: CGFloat { textMetrics.layoutValue(9) }
    private var currentTimeLineHeight: CGFloat { textMetrics.layoutValue(2) }
    private var calendarBottomScrollPadding: CGFloat { textMetrics.layoutValue(12) }
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
    }

    private func calendarLayout(for viewportWidth: CGFloat) -> (dayWidth: CGFloat, contentWidth: CGFloat) {
        let availableDayAreaWidth = max(viewportWidth - timeColumnWidth - trailingPadding, 0)
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
        HStack(alignment: .top, spacing: 0) {
            Text("all-day")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, height: allDayRowHeight, alignment: .trailing)
                .padding(.trailing, trailingPadding)

            ForEach(days, id: \.self) { day in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(
                        model.visibleAllDayEvents.filter { $0.intersectsDay(day, calendar: calendar) },
                        id: \.weekOccurrenceID
                    ) { event in
                        CalendarEventChip(event: event)
                            .eventDetailInteraction(
                                event: event,
                                selectedEvent: detailEventBinding(for: event),
                                showDetails: { showEventDetails(event) }
                            )
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
        ForEach(model.visibleTimedEvents, id: \.weekOccurrenceID) { event in
            if let frame = frame(for: event, dayWidth: dayWidth) {
                CalendarEventBlock(event: event)
                    .frame(width: max(dayWidth - trailingPadding, minimumEventWidth), height: frame.height, alignment: .topLeading)
                    .eventDetailInteraction(
                        event: event,
                        selectedEvent: detailEventBinding(for: event),
                        showDetails: { showEventDetails(event) }
                    )
                    .offset(x: frame.x, y: frame.y)
            }
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
        let duration = max(visibleEnd.timeIntervalSince(visibleStart), 0)
        let gridHeight = hourHeight * 24
        let startY = CGFloat(startOffset / 3600) * hourHeight
        let durationHeight = CGFloat(duration / 3600) * hourHeight
        let rawHeight = max(durationHeight - eventVerticalInset * 2, minimumEventHeight)
        let clampedHeight = min(rawHeight, gridHeight)
        let rawY = startY + eventVerticalInset
        let clampedY = min(max(rawY, 0), max(gridHeight - clampedHeight, 0))

        return (
            x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + eventHorizontalInset,
            y: clampedY,
            height: clampedHeight
        )
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
