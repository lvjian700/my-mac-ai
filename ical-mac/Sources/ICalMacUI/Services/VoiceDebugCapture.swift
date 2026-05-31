import AVFoundation
import Foundation

@MainActor
public final class VoiceDebugCapture: ObservableObject {
    public struct LevelSample: Sendable {
        public let timestamp: TimeInterval
        public let level: Double
    }

    @Published public var isEnabled = false
    @Published public private(set) var audioURL: URL?
    @Published public private(set) var samples: [LevelSample] = []
    @Published public private(set) var isCapturing = false

    // Written only on MainActor (startCapture/stopCapture); read only on the tap thread (append).
    // Access is serialized by the fact that startCapture runs before the tap is installed
    // and stopCapture runs after the tap is removed, so no concurrent access occurs.
    nonisolated(unsafe) private var _audioFile: AVAudioFile?
    private var captureStart: Date?

    public init() {}

    public func startCapture(format: AVAudioFormat) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_debug_\(Int(Date().timeIntervalSince1970))")
            .appendingPathExtension("wav")
        audioURL = url
        samples = []
        captureStart = Date()
        isCapturing = true
        _audioFile = try? AVAudioFile(forWriting: url, settings: format.settings)
    }

    nonisolated public func append(buffer: AVAudioPCMBuffer, timestamp: TimeInterval) {
        try? _audioFile?.write(from: buffer)
    }

    public func appendLevel(_ level: Double, at timestamp: TimeInterval) {
        guard isCapturing else { return }
        samples.append(LevelSample(timestamp: timestamp, level: level))
    }

    public func stopCapture() {
        _audioFile = nil
        isCapturing = false
    }

    public func levelsArray(at time: TimeInterval, maxCount: Int) -> [Double] {
        Array(samples.filter { $0.timestamp <= time }.suffix(maxCount).map { $0.level })
    }

    public var duration: TimeInterval {
        samples.last?.timestamp ?? 0
    }
}
