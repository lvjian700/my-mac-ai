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
    public var colorHex: String?

    public init(
        id: String,
        title: String,
        accountName: String,
        allowsContentModifications: Bool,
        colorHex: String? = nil
    ) {
        self.id = id
        self.title = title
        self.accountName = accountName
        self.allowsContentModifications = allowsContentModifications
        self.colorHex = colorHex
    }
}

public struct CalendarEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var isRecurring: Bool
    public var calendarTitle: String
    public var calendarIdentifier: String?
    public var location: String?
    public var notes: String?
    public var invitation: CalendarInvitationInfo?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        isRecurring: Bool = false,
        calendarTitle: String,
        calendarIdentifier: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        invitation: CalendarInvitationInfo? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.isRecurring = isRecurring
        self.calendarTitle = calendarTitle
        self.calendarIdentifier = calendarIdentifier
        self.location = location
        self.notes = notes
        self.invitation = invitation
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate
        case endDate
        case isAllDay
        case isRecurring
        case calendarTitle
        case calendarIdentifier
        case location
        case notes
        case invitation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            startDate: try container.decode(Date.self, forKey: .startDate),
            endDate: try container.decode(Date.self, forKey: .endDate),
            isAllDay: try container.decode(Bool.self, forKey: .isAllDay),
            isRecurring: try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false,
            calendarTitle: try container.decode(String.self, forKey: .calendarTitle),
            calendarIdentifier: try container.decodeIfPresent(String.self, forKey: .calendarIdentifier),
            location: try container.decodeIfPresent(String.self, forKey: .location),
            notes: try container.decodeIfPresent(String.self, forKey: .notes),
            invitation: try container.decodeIfPresent(CalendarInvitationInfo.self, forKey: .invitation)
        )
    }
}

public struct CalendarInvitationInfo: Codable, Equatable, Sendable {
    public var currentUserStatus: CalendarParticipantStatus
    public var responseStatus: CalendarInvitationResponseStatus
    public var organizerName: String?
    public var organizerURL: String?
    public var currentUserName: String?
    public var currentUserURL: String?
    public var attendeeCount: Int

    public var needsResponse: Bool {
        responseStatus == .needsAction || responseStatus == .unknown
    }

    public init(
        currentUserStatus: CalendarParticipantStatus,
        responseStatus: CalendarInvitationResponseStatus? = nil,
        organizerName: String? = nil,
        organizerURL: String? = nil,
        currentUserName: String? = nil,
        currentUserURL: String? = nil,
        attendeeCount: Int
    ) {
        self.currentUserStatus = currentUserStatus
        self.responseStatus = responseStatus ?? CalendarInvitationResponseStatus(participantStatus: currentUserStatus)
        self.organizerName = organizerName
        self.organizerURL = organizerURL
        self.currentUserName = currentUserName
        self.currentUserURL = currentUserURL
        self.attendeeCount = attendeeCount
    }

    private enum CodingKeys: String, CodingKey {
        case currentUserStatus
        case responseStatus
        case organizerName
        case organizerURL
        case currentUserName
        case currentUserURL
        case attendeeCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let currentUserStatus = try container.decode(CalendarParticipantStatus.self, forKey: .currentUserStatus)
        self.init(
            currentUserStatus: currentUserStatus,
            responseStatus: try container.decodeIfPresent(CalendarInvitationResponseStatus.self, forKey: .responseStatus),
            organizerName: try container.decodeIfPresent(String.self, forKey: .organizerName),
            organizerURL: try container.decodeIfPresent(String.self, forKey: .organizerURL),
            currentUserName: try container.decodeIfPresent(String.self, forKey: .currentUserName),
            currentUserURL: try container.decodeIfPresent(String.self, forKey: .currentUserURL),
            attendeeCount: try container.decode(Int.self, forKey: .attendeeCount)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentUserStatus, forKey: .currentUserStatus)
        try container.encode(responseStatus, forKey: .responseStatus)
        try container.encodeIfPresent(organizerName, forKey: .organizerName)
        try container.encodeIfPresent(organizerURL, forKey: .organizerURL)
        try container.encodeIfPresent(currentUserName, forKey: .currentUserName)
        try container.encodeIfPresent(currentUserURL, forKey: .currentUserURL)
        try container.encode(attendeeCount, forKey: .attendeeCount)
    }
}

public enum CalendarParticipantStatus: String, Codable, Equatable, Sendable {
    case unknown
    case pending
    case accepted
    case declined
    case tentative
    case delegated
    case completed
    case inProcess
}

public enum CalendarInvitationResponse: String, Sendable, Codable {
    case accept, decline, tentative
}

public enum CalendarInvitationResponseStatus: String, Codable, Equatable, Sendable {
    case unknown
    case needsAction
    case accepted
    case declined
    case tentative
    case delegated
    case completed
    case inProcess

    public init(participantStatus: CalendarParticipantStatus) {
        switch participantStatus {
        case .unknown:
            self = .unknown
        case .pending:
            self = .needsAction
        case .accepted:
            self = .accepted
        case .declined:
            self = .declined
        case .tentative:
            self = .tentative
        case .delegated:
            self = .delegated
        case .completed:
            self = .completed
        case .inProcess:
            self = .inProcess
        }
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
