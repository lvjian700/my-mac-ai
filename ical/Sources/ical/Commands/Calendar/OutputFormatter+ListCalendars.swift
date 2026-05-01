import Foundation

extension OutputFormatter {
    // MARK: - Calendars

    static func printCalendarsGrouped(_ groups: [CalendarGroup], format: OutputFormat) {
        switch format {
        case .text:
            for group in groups {
                print(group.accountName)
                for cal in group.calendars {
                    print("  \(cal.title)")
                }
            }
        case .json:
            let dicts = groups.flatMap { group in
                group.calendars.map { ["account": group.accountName, "title": $0.title] }
            }
            printJSON(dicts)
        }
    }
}
