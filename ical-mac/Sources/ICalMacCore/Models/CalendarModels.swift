import Foundation

public enum CalendarAccessStatus: String, Codable, Sendable {
    case notDetermined
    case granted
    case denied
}

public struct CalendarInfo: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var accountName: String
    public var allowsContentModifications: Bool

    public init(
        id: String,
        title: String,
        accountName: String,
        allowsContentModifications: Bool
    ) {
        self.id = id
        self.title = title
        self.accountName = accountName
        self.allowsContentModifications = allowsContentModifications
    }
}

public struct CalendarEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var calendarTitle: String
    public var calendarIdentifier: String?
    public var location: String?
    public var notes: String?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarTitle: String,
        calendarIdentifier: String? = nil,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.calendarIdentifier = calendarIdentifier
        self.location = location
        self.notes = notes
    }
}

public struct CalendarQuery: Codable, Equatable, Sendable {
    public var startDate: Date
    public var endDate: Date
    public var calendarTitles: [String]

    public init(startDate: Date, endDate: Date, calendarTitles: [String] = []) {
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitles = calendarTitles
    }
}

public struct EventDraft: Codable, Equatable, Sendable {
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var calendarTitle: String?
    public var location: String?
    public var notes: String?
    public var isAllDay: Bool

    public init(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        isAllDay: Bool = false
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.location = location
        self.notes = notes
        self.isAllDay = isAllDay
    }
}

public struct EventUpdate: Codable, Equatable, Sendable {
    public var id: String
    public var title: String?
    public var startDate: Date?
    public var endDate: Date?
    public var calendarTitle: String?
    public var location: String?
    public var notes: String?
    public var isAllDay: Bool?

    public init(
        id: String,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        calendarTitle: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        isAllDay: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.location = location
        self.notes = notes
        self.isAllDay = isAllDay
    }
}

public struct SessionSnapshot: Codable, Equatable, Sendable {
    public var events: [CalendarEvent]
    public var syncedAt: Date
    public var range: CalendarQuery

    public init(events: [CalendarEvent], syncedAt: Date, range: CalendarQuery) {
        self.events = events
        self.syncedAt = syncedAt
        self.range = range
    }
}
