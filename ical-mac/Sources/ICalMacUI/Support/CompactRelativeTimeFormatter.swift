import Foundation

struct CompactRelativeTimeFormatter: Sendable {
    func string(from date: Date, relativeTo now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))

        if seconds < 60 {
            return "now"
        }

        if seconds < 3_600 {
            return "\(max(1, Int(seconds / 60)))m"
        }

        if seconds < 86_400 {
            return "\(max(1, Int(seconds / 3_600)))h"
        }

        if seconds < 604_800 {
            return "\(max(1, Int(seconds / 86_400)))d"
        }

        if seconds < 2_592_000 {
            return "\(max(1, Int(seconds / 604_800)))w"
        }

        if seconds < 31_536_000 {
            return "\(max(1, Int(seconds / 2_592_000)))mo"
        }

        return "\(max(1, Int(seconds / 31_536_000)))y"
    }
}
