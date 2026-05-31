import SwiftUI

struct VoiceTimelineWaveform: View {
    let levels: [Double]
    let isPreparing: Bool
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let barMinHeight: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
            Canvas { ctx, size in
                drawBaseline(in: ctx, size: size)
                drawBars(in: ctx, size: size)
            }
        }
    }

    private func drawBaseline(in ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        ctx.stroke(path, with: .color(.secondary.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2.2, 4]))
    }

    private func drawBars(in ctx: GraphicsContext, size: CGSize) {
        let maxCount = max(1, Int(size.width / (barWidth + barSpacing)))
        let bars = Array(levels.suffix(maxCount))
        for (i, level) in bars.enumerated() {
            let h = barHeight(level: level, totalHeight: size.height)
            let x = CGFloat(i) * (barWidth + barSpacing)
            let y = (size.height - h) / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: h)
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
            ctx.fill(path, with: .color(.primary.opacity(0.80)))
        }
    }

    private func barHeight(level: Double, totalHeight: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, level))
        return max(2, totalHeight * CGFloat(barMinHeight + clamped * (1 - barMinHeight)))
    }
}
