import ICalMacCore
import SwiftUI

struct CalendarEventCategoryPresentation: Equatable {
    var category: CalendarEventCategory
    var label: String
    var color: Color

    static func make(for event: CalendarEvent) -> CalendarEventCategoryPresentation {
        make(forTitle: event.title)
    }

    static func make(forTitle title: String) -> CalendarEventCategoryPresentation {
        let category = CalendarEventCategory.detected(in: title)
        return CalendarEventCategoryPresentation(
            category: category,
            label: category.label,
            color: category.color
        )
    }
}

enum CalendarEventCategory: String, Equatable, CaseIterable {
    case focus
    case catchup
    case support
    case meeting
    case personal
    case rest
    case outOfOffice

    var label: String {
        switch self {
        case .focus:
            "Focus"
        case .catchup:
            "Catchup"
        case .support:
            "Support"
        case .meeting:
            "Meeting"
        case .personal:
            "Personal"
        case .rest:
            "Rest"
        case .outOfOffice:
            "Out of office"
        }
    }

    var color: Color {
        switch self {
        case .focus:
            Color(red: 0.22, green: 0.23, blue: 0.25)
        case .catchup:
            Color(red: 0.08, green: 0.48, blue: 0.27)
        case .support:
            Color(red: 0.54, green: 0.27, blue: 0.78)
        case .meeting:
            Color(red: 0.16, green: 0.39, blue: 0.86)
        case .personal:
            Color(red: 0.78, green: 0.56, blue: 0.04)
        case .rest:
            Color(red: 0.88, green: 0.36, blue: 0.05)
        case .outOfOffice:
            Color(red: 0.76, green: 0.16, blue: 0.22)
        }
    }

    static func detected(in title: String) -> CalendarEventCategory {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for rule in detectionRules where rule.prefixes.contains(where: { hasPrefix($0, in: normalizedTitle) }) {
            return rule.category
        }
        return .meeting
    }

    private static let detectionRules: [(category: CalendarEventCategory, prefixes: [String])] = [
        (.outOfOffice, ["out of office"]),
        (.focus, ["focus", "focus time"]),
        (.catchup, ["catchup", "sync", "tech huddle"]),
        (.support, ["support", "cop", "oncall"]),
        (.personal, ["lunch", "personal"]),
        (.rest, ["break", "offscreen"]),
    ]

    private static func hasPrefix(_ prefix: String, in title: String) -> Bool {
        guard title.hasPrefix(prefix) else { return false }
        let suffix = title.dropFirst(prefix.count)
        guard let nextCharacter = suffix.first else { return true }
        return nextCharacter.isWhitespace || prefixSeparators.contains(nextCharacter)
    }

    private static let prefixSeparators = CharacterSet(charactersIn: "-:–—|/")
}

private extension CharacterSet {
    func contains(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { self.contains($0) }
    }
}
