import SwiftUI

public struct ReadingTextMetrics: Equatable, Sendable {
    public var scale: CGFloat

    public init(scale: CGFloat = 1) {
        self.scale = max(0.75, min(scale, 3.2))
    }

    public func value(_ baseValue: CGFloat) -> CGFloat {
        baseValue * scale
    }

    public func layoutValue(_ baseValue: CGFloat) -> CGFloat {
        baseValue * min(scale, 1.45)
    }

    public func font(_ style: ReadingTextStyle, weight: Font.Weight? = nil) -> Font {
        .system(size: value(style.baseSize), weight: weight ?? style.defaultWeight)
    }
}

public enum ReadingTextStyle: Sendable {
    case caption2
    case caption
    case callout
    case body
    case headline
    case title3
    case title2
    case largeTitle

    var baseSize: CGFloat {
        switch self {
        case .caption2: 11
        case .caption: 12
        case .callout: 12
        case .body: 13
        case .headline: 13
        case .title3: 17
        case .title2: 22
        case .largeTitle: 26
        }
    }

    var defaultWeight: Font.Weight {
        switch self {
        case .headline:
            .semibold
        case .largeTitle:
            .semibold
        default:
            .regular
        }
    }
}

private struct ReadingTextMetricsKey: EnvironmentKey {
    static let defaultValue = ReadingTextMetrics()
}

public extension EnvironmentValues {
    var readingTextMetrics: ReadingTextMetrics {
        get { self[ReadingTextMetricsKey.self] }
        set { self[ReadingTextMetricsKey.self] = newValue }
    }
}
