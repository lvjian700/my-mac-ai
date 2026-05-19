import SwiftUI

extension Color {
    init?(calendarHex: String?) {
        guard let calendarHex else { return nil }
        let value = calendarHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = Int(value, radix: 16) else { return nil }

        self.init(
            red: Double((number >> 16) & 0xFF) / 255.0,
            green: Double((number >> 8) & 0xFF) / 255.0,
            blue: Double(number & 0xFF) / 255.0
        )
    }
}
