import Testing
@testable import ICalMac

struct CalendarEventCategoryPresentationTests {
    @Test func mapsCategoryPrefixesToCalendarThemes() {
        #expect(CalendarEventCategory.detected(in: "Focus - Deep work") == .focus)
        #expect(CalendarEventCategory.detected(in: "Focus time - Deep work") == .focus)
        #expect(CalendarEventCategory.detected(in: "Catchup - Nina") == .catchup)
        #expect(CalendarEventCategory.detected(in: "Sync: Launch notes") == .catchup)
        #expect(CalendarEventCategory.detected(in: "Tech Huddle - Runtime") == .catchup)
        #expect(CalendarEventCategory.detected(in: "Support - Handoff") == .support)
        #expect(CalendarEventCategory.detected(in: "Cop - Incident review") == .support)
        #expect(CalendarEventCategory.detected(in: "Oncall - Primary") == .support)
        #expect(CalendarEventCategory.detected(in: "Lunch with Sarah") == .personal)
        #expect(CalendarEventCategory.detected(in: "Personal - School pickup") == .personal)
        #expect(CalendarEventCategory.detected(in: "Break - Walk") == .rest)
        #expect(CalendarEventCategory.detected(in: "Offscreen - Writing") == .rest)
        #expect(CalendarEventCategory.detected(in: "Out of office - Travel") == .outOfOffice)
    }

    @Test func defaultsUnknownPrefixesToMeeting() {
        #expect(CalendarEventCategory.detected(in: "Product review") == .meeting)
        #expect(CalendarEventCategoryPresentation.make(forTitle: "Roadmap").label == "Meeting")
    }

    @Test func matchesCategoryPrefixesCaseInsensitively() {
        #expect(CalendarEventCategory.detected(in: "FOCUS TIME - Deep work") == .focus)
        #expect(CalendarEventCategory.detected(in: "sync: Launch notes") == .catchup)
        #expect(CalendarEventCategory.detected(in: "Tech huddle - Runtime") == .catchup)
        #expect(CalendarEventCategory.detected(in: "ONCALL - Primary") == .support)
        #expect(CalendarEventCategory.detected(in: "personal - School pickup") == .personal)
        #expect(CalendarEventCategory.detected(in: "OFFSCREEN - Writing") == .rest)
        #expect(CalendarEventCategory.detected(in: "OUT OF OFFICE - Travel") == .outOfOffice)
    }

    @Test func mapsInlineSymbolsForBlockingCategories() {
        #expect(CalendarEventCategoryPresentation.make(forTitle: "Focus - Planning").symbolName == "scope")
        #expect(CalendarEventCategoryPresentation.make(forTitle: "Out of office - Travel").symbolName == "minus.circle.fill")
        #expect(CalendarEventCategoryPresentation.make(forTitle: "Sync - Launch notes").symbolName == nil)
    }
}
