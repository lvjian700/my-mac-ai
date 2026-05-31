import AVFoundation
import SwiftUI

public struct VoiceInputDevMenuView: View {
    @ObservedObject public var capture: VoiceDebugCapture
    @ObservedObject public var settings: VoiceInputSettings

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0

    public init(capture: VoiceDebugCapture, settings: VoiceInputSettings) {
        self.capture = capture
        self.settings = settings
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                captureSection
                Divider()
                replaySection
                Divider()
                gateSection
                Divider()
                animationSection
            }
            .padding(20)
        }
        .frame(minWidth: 460, minHeight: 500)
        .onReceive(
            Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
        ) { _ in
            guard isPlaying, let p = player else { return }
            currentTime = p.currentTime
            if !p.isPlaying { isPlaying = false }
        }
    }

    // MARK: - Capture

    private var captureSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Capture").font(.headline)
                if let url = capture.audioURL {
                    Text("\(capture.samples.count) samples · \(formatDuration(capture.duration)) · \(url.lastPathComponent)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No session captured yet").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Auto-capture", isOn: $capture.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    // MARK: - Replay

    private var replaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Replay").font(.headline)

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
                Canvas { ctx, size in
                    let t = isPlaying ? (player?.currentTime ?? currentTime) : currentTime
                    let maxCount = max(1, Int(size.width / (settings.barWidth + settings.barSpacing)))
                    let levels = capture.levelsArray(at: t, maxCount: maxCount)
                    drawWaveform(in: ctx, size: size, levels: levels)
                }
                .frame(height: 44)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Slider(
                value: Binding(
                    get: { capture.duration > 0 ? min(1, currentTime / capture.duration) : 0 },
                    set: { seek(to: $0 * capture.duration) }
                )
            )
            .disabled(capture.duration == 0)

            HStack(spacing: 12) {
                Button(isPlaying ? "Pause" : "Play") { togglePlayback() }
                    .disabled(capture.audioURL == nil)

                Text(formatDuration(currentTime) + " / " + formatDuration(capture.duration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                if let sample = closestSample(at: currentTime) {
                    Text("level \(String(format: "%.3f", sample.level))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Gate Sliders

    private var gateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Gate").font(.headline)

            SliderRow("Gate threshold", value: $settings.gateThreshold, in: 0...0.15, format: "%.3f")
            SliderRow("Speech threshold", value: $settings.speechThreshold, in: 0...0.5, format: "%.2f")
            SliderRow("Rise blend", value: $settings.riseBlend, in: 0.1...0.95, format: "%.2f")
            SliderRow("Fall decay", value: $settings.fallDecay, in: 0.1...0.95, format: "%.2f")
            SliderRow("Expansion exponent", value: $settings.expansionExponent, in: 0.2...1.5, format: "%.2f")
            SliderRow("Gain", value: $settings.gain, in: 0.5...3.0, format: "%.2f")
        }
    }

    // MARK: - Animation Sliders

    private var animationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation").font(.headline)

            SliderRow("Bar min height", value: $settings.barMinHeight, in: 0...0.4, format: "%.2f")
            SliderRow("Bar width (px)", value: $settings.barWidth, in: 1.5...8.0, format: "%.1f")
            SliderRow("Bar spacing (px)", value: $settings.barSpacing, in: 0.5...6.0, format: "%.1f")

            HStack {
                Spacer()
                Button("Reset to Defaults") { settings.resetToDefaults() }
            }
        }
    }

    // MARK: - Canvas Draw

    private func drawWaveform(in ctx: GraphicsContext, size: CGSize, levels: [Double]) {
        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: size.height / 2))
        baseline.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        ctx.stroke(baseline, with: .color(.secondary.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2.2, 4]))

        let bw = CGFloat(settings.barWidth)
        let bs = CGFloat(settings.barSpacing)
        let minH = settings.barMinHeight

        for (i, level) in levels.enumerated() {
            let clamped = max(0, min(1, level))
            let h = max(2, size.height * CGFloat(minH + clamped * (1 - minH)))
            let x = CGFloat(i) * (bw + bs)
            let y = (size.height - h) / 2
            let path = Path(roundedRect: CGRect(x: x, y: y, width: bw, height: h),
                            cornerRadius: bw / 2)
            ctx.fill(path, with: .color(.primary.opacity(0.80)))
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if player == nil, let url = capture.audioURL {
                player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
            }
            player?.currentTime = currentTime
            player?.play()
            isPlaying = true
        }
    }

    private func seek(to time: TimeInterval) {
        currentTime = max(0, min(capture.duration, time))
        player?.currentTime = currentTime
    }

    private func closestSample(at time: TimeInterval) -> VoiceDebugCapture.LevelSample? {
        capture.samples.last { $0.timestamp <= time } ?? capture.samples.first
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        let frac = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", mins, secs, frac)
    }
}

// MARK: - Slider Row

private struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    init(_ label: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) {
        self.label = label
        self._value = value
        self.range = range
        self.format = format
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .frame(width: 160, alignment: .leading)
                .font(.system(size: 12))
            Slider(value: $value, in: range)
            Text(String(format: format, value))
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 44, alignment: .trailing)
        }
    }
}
