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

    private let headerBottomPadding: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            WeekHeaderView()
                .padding(.horizontal)
                .padding(.bottom, headerBottomPadding)

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

    private let headerSpacing: CGFloat = 16
    private let minHeight: CGFloat = 66

    var body: some View {
        HStack(spacing: headerSpacing) {
            calendarTitle
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            navigationControls
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
    }

    private var calendarTitle: Text {
        Text(Self.monthFormatter.string(from: model.displayedWeekStartDate))
            .font(.system(size: 34, weight: .bold))
        + Text(" \(Self.yearFormatter.string(from: model.displayedWeekStartDate))")
            .font(.system(size: 34, weight: .regular))
    }

    private var navigationControls: some View {
        HStack(spacing: 6) {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            HStack(spacing: 4) {
                CalendarNavIconButton(systemImage: "chevron.left", accessibilityLabel: "Previous Week") {
                    Task { await model.moveDisplayedWeek(by: -1) }
                }

                Button {
                    Task { await model.showToday() }
                } label: {
                    Text("Today")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(height: 28)
                        .padding(.horizontal, 17)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Today")

                CalendarNavIconButton(systemImage: "chevron.right", accessibilityLabel: "Next Week") {
                    Task { await model.moveDisplayedWeek(by: 1) }
                }
            }
            .disabled(model.isRefreshing)
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}

private struct CalendarNavIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct WeekGridView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.readingTextMetrics) private var textMetrics
    @State private var selectedDetailEvent: CalendarEvent?

    private let calendar = Calendar.current

    private var hourHeight: CGFloat { 58 }
    private var timeColumnWidth: CGFloat { textMetrics.layoutValue(72) }
    private var minimumDayWidth: CGFloat { textMetrics.layoutValue(92) }
    private var dayHeaderHeight: CGFloat { 44 }
    private var dayHeaderVerticalPadding: CGFloat { 0 }
    private var trailingPadding: CGFloat { 8 }
    private var allDayEventHeight: CGFloat { 28 }
    private var allDayEventHorizontalPadding: CGFloat { 3 }
    private var allDayEventVerticalPadding: CGFloat { 5 }
    private var allDayRowHeight: CGFloat { 40 }
    private var allDaySeparatorHeight: CGFloat { 2 }
    private var hourLabelOffset: CGFloat { textMetrics.layoutValue(7) }
    private var eventHorizontalInset: CGFloat { 4 }
    private var eventVerticalInset: CGFloat { 1 }
    private var minimumEventWidth: CGFloat { 44 }
    private var minimumEventHeight: CGFloat { textMetrics.layoutValue(28) }
    private var currentTimeLabelHeight: CGFloat { textMetrics.layoutValue(28) }
    private var currentTimeDotSide: CGFloat { textMetrics.layoutValue(9) }
    private var currentTimeLineHeight: CGFloat { textMetrics.layoutValue(2) }
    private var calendarBottomScrollPadding: CGFloat { textMetrics.layoutValue(12) }

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
                    Divider()
                    allDayRow(dayWidth: dayWidth)
                        .frame(width: contentWidth)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(width: contentWidth, height: allDaySeparatorHeight)
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, height: allDayRowHeight, alignment: .trailing)
                .padding(.trailing, trailingPadding)

            ForEach(days, id: \.self) { day in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.visibleAllDayEvents.filter { $0.intersectsDay(day, calendar: calendar) }) { event in
                        let color = Color(calendarHex: model.colorHex(for: event)) ?? .accentColor
                        EventChip(event: event, color: color)
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

    @ViewBuilder
    private func currentTimeScrollTarget(now: Date, contentWidth: CGFloat) -> some View {
        if currentDayIndex(for: now) != nil {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: currentTimeYPosition(for: now))
                Color.clear
                    .frame(width: contentWidth, height: 1)
                    .id(Self.currentTimeScrollTargetID)
                Spacer(minLength: 0)
            }
            .frame(width: contentWidth, height: hourHeight * 24, alignment: .top)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func currentTimeIndicator(now: Date, dayWidth: CGFloat, contentWidth: CGFloat) -> some View {
        if let dayIndex = currentDayIndex(for: now) {
            let yPosition = currentTimeYPosition(for: now)
            let todayX = timeColumnWidth + CGFloat(dayIndex) * dayWidth
            let gridWidth = max(contentWidth - timeColumnWidth, 0)
            let labelY = min(max(yPosition - currentTimeLabelHeight / 2, 0), hourHeight * 24 - currentTimeLabelHeight)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.red.opacity(0.16))
                    .frame(width: gridWidth, height: 1)
                    .offset(x: timeColumnWidth, y: yPosition)

                Rectangle()
                    .fill(Color.red)
                    .frame(width: dayWidth, height: currentTimeLineHeight)
                    .offset(x: todayX, y: yPosition - currentTimeLineHeight / 2)

                Circle()
                    .fill(Color.red)
                    .frame(width: currentTimeDotSide, height: currentTimeDotSide)
                    .offset(x: todayX - currentTimeDotSide / 2, y: yPosition - currentTimeDotSide / 2)

                Text(Self.currentTimeFormatter.string(from: now))
                    .font(textMetrics.font(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, textMetrics.layoutValue(6))
                    .frame(height: currentTimeLabelHeight)
                    .background(Color.red, in: Capsule())
                    .frame(width: timeColumnWidth - trailingPadding, alignment: .trailing)
                    .offset(y: labelY)
            }
            .allowsHitTesting(false)
        }
    }

    private func eventBlocks(dayWidth: CGFloat) -> some View {
        ForEach(model.visibleTimedEvents) { event in
            if let frame = frame(for: event, dayWidth: dayWidth) {
                let color = Color(calendarHex: model.colorHex(for: event)) ?? .accentColor
                EventBlock(event: event, color: color)
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

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }()

    private static let currentTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    private static let currentTimeScrollTargetID = "current-time-scroll-target"
}

private struct DayColumnHeader: View {
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

private extension View {
    func eventDetailInteraction(
        event: CalendarEvent,
        selectedEvent: Binding<CalendarEvent?>,
        showDetails: @escaping () -> Void
    ) -> some View {
        modifier(
            EventDetailInteractionModifier(
                event: event,
                selectedEvent: selectedEvent,
                showDetails: showDetails
            )
        )
    }
}

private struct EventDetailInteractionModifier: ViewModifier {
    let event: CalendarEvent
    @Binding var selectedEvent: CalendarEvent?
    let showDetails: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture(count: 2)
                    .onEnded(showDetails)
            )
            .contextMenu {
                Button(action: showDetails) {
                    Label("Show Details", systemImage: "info.circle")
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                showDetails()
            }
            .accessibilityAction(named: Text("Show Details"), showDetails)
            .popover(item: $selectedEvent, arrowEdge: .trailing) { event in
                CalendarEventDetailView(event: event)
            }
    }
}

private struct CalendarEventDetailView: View {
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

            CalendarEventDetailSegment(text: formattedTime, isPlaceholder: false)

            CalendarEventDetailSegment(text: "Add Invitees", isPlaceholder: true)

            CalendarEventDetailSegment(text: notesText, isPlaceholder: !hasNotes)
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
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

private struct CalendarEventDetailAccessory: View {
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

private struct CalendarEventDetailSegment: View {
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

private enum CalendarEventDetailStyle {
    static let segmentFill = Color.secondary.opacity(0.07)
}

private extension CalendarEvent {
    func intersectsDay(_ day: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return startDate < end && endDate > start
    }
}
