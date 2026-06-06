import Foundation
import SwiftUI

#if DEBUG
#Preview("Voice Controls - Recording") {
    RecordingControlsView(
        audioLevels: PreviewData.voiceInputLevels,
        elapsedSeconds: 47,
        isPreparing: false,
        canSubmit: true,
        stopAction: {},
        submitAction: {}
    )
    .frame(width: 420)
    .padding()
}

#Preview("Voice Controls - Preparing") {
    RecordingControlsView(
        audioLevels: [],
        elapsedSeconds: 0,
        isPreparing: true,
        canSubmit: false,
        stopAction: {},
        submitAction: {}
    )
    .frame(width: 420)
    .padding()
}

#Preview("Voice Status") {
    VStack(alignment: .leading, spacing: 10) {
        VoiceInputInlineStatusView(state: .idle)
        VoiceInputInlineStatusView(state: .requestingPermission)
        VoiceInputInlineStatusView(state: .transcribing)
        VoiceInputInlineStatusView(state: .failed("Could not transcribe audio"))
        VoiceInputInlineStatusView(state: .unavailable("Speech recognition is unavailable"))
    }
    .frame(width: 360)
    .padding()
}
#endif

struct RecordingControlsView: View {
    let audioLevels: [Double]
    let elapsedSeconds: TimeInterval
    let isPreparing: Bool
    let canSubmit: Bool
    var stopAction: () -> Void
    var submitAction: () -> Void

    private let controlsSpacing: CGFloat = 6
    private let buttonSide: CGFloat = 30
    private let timelineHeight: CGFloat = 22

    var body: some View {
        HStack(spacing: controlsSpacing) {
            VoiceTimelineWaveform(levels: audioLevels, isPreparing: isPreparing)
                .frame(maxWidth: .infinity, minHeight: timelineHeight, maxHeight: timelineHeight)

            Text(Self.durationFormatter.string(from: elapsedSeconds) ?? "0:00")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 34, alignment: .trailing)

            Button(action: stopAction) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: buttonSide, height: buttonSide)
                    .foregroundStyle(.primary.opacity(0.78))
                    .background {
                        Circle()
                            .fill(Color.secondary.opacity(0.12))
                    }
            }
            .buttonStyle(.plain)
            .help("Stop dictation")

            Button(action: submitAction) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: buttonSide, height: buttonSide)
                    .foregroundStyle(canSubmit ? .white : .secondary.opacity(0.55))
                    .background {
                        Circle()
                            .fill(canSubmit ? Color.accentColor : Color.accentColor.opacity(0.13))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .help("Send")
        }
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}

struct VoiceInputInlineStatusView: View {
    let state: VoiceInputState

    private let statusSpacing: CGFloat = 6
    private let iconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: statusSpacing) {
            statusSymbol
                .frame(width: iconSize, height: iconSize)

            statusText
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 26, alignment: .center)
    }

    @ViewBuilder
    private var statusSymbol: some View {
        switch state {
        case .requestingPermission, .transcribing:
            ProgressView()
                .controlSize(.small)
        case .unavailable, .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .idle, .recording:
            Color.clear
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch state {
        case .requestingPermission:
            Text("Requesting voice access")
        case .transcribing:
            Text("Transcribing")
        case .unavailable(let message), .failed(let message):
            Text(message)
        case .idle, .recording:
            Text("")
        }
    }
}

private struct VoiceTimelineWaveform: View {
    let levels: [Double]
    let isPreparing: Bool

    private let barWidth: CGFloat = 3.0
    private let barSpacing: CGFloat = 2.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { ctx, size in
                drawBaseline(in: ctx, size: size)
                drawBars(in: ctx, size: size, date: context.date)
            }
        }
    }

    private func drawBaseline(in ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        ctx.stroke(
            path,
            with: .color(.secondary.opacity(0.35)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2.2, 4])
        )
    }

    private func drawBars(in ctx: GraphicsContext, size: CGSize, date: Date) {
        let count = max(1, Int(size.width / (barWidth + barSpacing)))
        let bars = displayLevels(count: count, at: date)
        let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * barSpacing
        let startX = (size.width - totalWidth) / 2

        for (i, level) in bars.enumerated() {
            let h = barHeight(level: level, totalHeight: size.height)
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = (size.height - h) / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: h)
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
            ctx.fill(path, with: .color(.primary.opacity(0.80)))
        }
    }

    private func displayLevels(count: Int, at date: Date) -> [Double] {
        let recent = Array(levels.suffix(count))
        if recent.count < count {
            return Array(repeating: 0.0, count: count - recent.count) + recent
        }
        return recent
    }

    private func barHeight(level: Double, totalHeight: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, level))
        return max(2, totalHeight * CGFloat(0.08 + clamped * 0.92))
    }
}
