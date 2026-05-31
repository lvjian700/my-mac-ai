import Foundation

@MainActor
public final class VoiceInputSettings: ObservableObject {
    // MARK: - Voice Gate

    @Published public var gateThreshold: Double {
        didSet { UserDefaults.standard.set(gateThreshold, forKey: Keys.gateThreshold) }
    }
    @Published public var speechThreshold: Double {
        didSet { UserDefaults.standard.set(speechThreshold, forKey: Keys.speechThreshold) }
    }
    @Published public var riseBlend: Double {
        didSet { UserDefaults.standard.set(riseBlend, forKey: Keys.riseBlend) }
    }
    @Published public var fallDecay: Double {
        didSet { UserDefaults.standard.set(fallDecay, forKey: Keys.fallDecay) }
    }
    @Published public var expansionExponent: Double {
        didSet { UserDefaults.standard.set(expansionExponent, forKey: Keys.expansionExponent) }
    }
    @Published public var gain: Double {
        didSet { UserDefaults.standard.set(gain, forKey: Keys.gain) }
    }

    // MARK: - Animation

    @Published public var barMinHeight: Double {
        didSet { UserDefaults.standard.set(barMinHeight, forKey: Keys.barMinHeight) }
    }
    @Published public var barWidth: Double {
        didSet { UserDefaults.standard.set(barWidth, forKey: Keys.barWidth) }
    }
    @Published public var barSpacing: Double {
        didSet { UserDefaults.standard.set(barSpacing, forKey: Keys.barSpacing) }
    }

    // MARK: - Init

    public init() {
        let d = UserDefaults.standard
        gateThreshold     = d.value(forKey: Keys.gateThreshold)     as? Double ?? Defaults.gateThreshold
        speechThreshold   = d.value(forKey: Keys.speechThreshold)   as? Double ?? Defaults.speechThreshold
        riseBlend         = d.value(forKey: Keys.riseBlend)         as? Double ?? Defaults.riseBlend
        fallDecay         = d.value(forKey: Keys.fallDecay)         as? Double ?? Defaults.fallDecay
        expansionExponent = d.value(forKey: Keys.expansionExponent) as? Double ?? Defaults.expansionExponent
        gain              = d.value(forKey: Keys.gain)              as? Double ?? Defaults.gain
        barMinHeight      = d.value(forKey: Keys.barMinHeight)      as? Double ?? Defaults.barMinHeight
        barWidth          = d.value(forKey: Keys.barWidth)          as? Double ?? Defaults.barWidth
        barSpacing        = d.value(forKey: Keys.barSpacing)        as? Double ?? Defaults.barSpacing
    }

    public func resetToDefaults() {
        gateThreshold     = Defaults.gateThreshold
        speechThreshold   = Defaults.speechThreshold
        riseBlend         = Defaults.riseBlend
        fallDecay         = Defaults.fallDecay
        expansionExponent = Defaults.expansionExponent
        gain              = Defaults.gain
        barMinHeight      = Defaults.barMinHeight
        barWidth          = Defaults.barWidth
        barSpacing        = Defaults.barSpacing
    }

    // MARK: - Constants

    private enum Keys {
        static let gateThreshold     = "voice.gateThreshold"
        static let speechThreshold   = "voice.speechThreshold"
        static let riseBlend         = "voice.riseBlend"
        static let fallDecay         = "voice.fallDecay"
        static let expansionExponent = "voice.expansionExponent"
        static let gain              = "voice.gain"
        static let barMinHeight      = "voice.barMinHeight"
        static let barWidth          = "voice.barWidth"
        static let barSpacing        = "voice.barSpacing"
    }

    public enum Defaults {
        public static let gateThreshold:     Double = 0.05
        public static let speechThreshold:   Double = 0.18
        public static let riseBlend:         Double = 0.65
        public static let fallDecay:         Double = 0.55
        public static let expansionExponent: Double = 0.58
        public static let gain:              Double = 1.25
        public static let barMinHeight:      Double = 0.08
        public static let barWidth:          Double = 3.0
        public static let barSpacing:        Double = 2.0
    }
}
