import SwiftUI

extension DynamicTypeSize {
    var bodyPointSize: CGFloat {
        switch self {
        case .xSmall: 12
        case .small: 13
        case .medium: 14
        case .large: 16
        case .xLarge: 18
        case .xxLarge: 20
        case .xxxLarge: 22
        case .accessibility1: 24
        case .accessibility2: 26
        case .accessibility3: 28
        case .accessibility4: 34
        case .accessibility5: 40
        @unknown default: 14
        }
    }
}
