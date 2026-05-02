import Foundation

struct DateParser {
    static func parse(_ string: String, endOfDay: Bool = false) throws -> Date {
        let trimmed = string.trimmingCharacters(in: .whitespaces).lowercased()
        switch trimmed {
        case "today":
            let day = Calendar.current.startOfDay(for: Date())
            return endOfDay ? lastSecondOfDay(day) : day
        case "tomorrow":
            let day = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            )
            return endOfDay ? lastSecondOfDay(day) : day
        default:
            break
        }
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone.current
        if let d = iso.date(from: string) { return d }
        let dtf = DateFormatter()
        dtf.locale = Locale(identifier: "en_US_POSIX")
        dtf.timeZone = TimeZone.current
        dtf.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = dtf.date(from: string) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: string) { return endOfDay ? lastSecondOfDay(d) : d }
        throw IcalError.invalidDate(string: string)
    }

    private static func lastSecondOfDay(_ date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        return Calendar.current.date(from: comps)!
    }
}
