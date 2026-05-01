import Foundation

struct DateParser {
    static func parse(_ string: String) throws -> Date {
        let trimmed = string.trimmingCharacters(in: .whitespaces).lowercased()
        switch trimmed {
        case "today":
            return Calendar.current.startOfDay(for: Date())
        case "tomorrow":
            return Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            )
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
        if let d = df.date(from: string) { return d }
        throw IcalError.invalidDate(string: string)
    }
}
