import SwiftUI

/// A short, transparent vector burst shown after the reminder windows close.
struct ConfettiCelebrationView: View {
    static let duration: TimeInterval = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let startedAt: Date
    var preview = false
    var servingML = 250
    var snapshotTime: TimeInterval?
    var snapshotReduceMotion = false
    private var still: Bool { reduceMotion || snapshotReduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: still || snapshotTime != nil)) { timeline in
            let elapsed = snapshotTime ?? max(0, timeline.date.timeIntervalSince(startedAt))
            ZStack(alignment: .top) {
                if !still {
                    Canvas { context, size in drawConfetti(context, size: size, elapsed: elapsed) }
                        .accessibilityHidden(true)
                }
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 21)).foregroundStyle(Palette.mint)
                    Text(preview ? "效果预览 · 不记水" : "喝水完成 · +\(servingML) mL")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 13)
                .background(Palette.ocean.opacity(0.94), in: Capsule())
                .overlay(Capsule().stroke(Palette.mint.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 7)
                .padding(.top, 60)
                .opacity(still ? 1 : min(1, elapsed / 0.18) * min(1, max(0, (Self.duration - elapsed) / 0.4)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func drawConfetti(_ context: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        guard elapsed >= 0, elapsed < Self.duration else { return }
        let colors = [Color(hex: 0xFFCA53), Color(hex: 0xFF6B8A), Color(hex: 0x66D8CC),
                      Color(hex: 0xA998FF), Color(hex: 0x68C9FF), Color(hex: 0xFFE9A9), Color(hex: 0xF18FD5)]
        let scale = min(max(min(size.width / 1440, size.height / 900), 0.65), 1.7)
        for index in 0..<520 {
            let side = index.isMultiple(of: 2) ? -1.0 : 1.0
            let falling = index >= 350
            let delay = falling ? 0.15 + random(index, 1) * 0.55 : random(index, 1) * 0.2
            let t = elapsed - delay
            guard t >= 0 else { continue }
            let life = falling ? 3.0 : 2.45 + random(index, 2) * 0.55
            guard t < life else { continue }
            let depth = 0.55 + random(index, 3) * 0.95
            let flutter = sin(t * (3 + random(index, 6) * 3) + random(index, 12) * .pi * 2)
            let x: CGFloat
            let y: CGFloat
            if falling {
                // A broad overhead shower fills the gaps between the cannons.
                x = size.width * (random(index, 4) + t * (random(index, 13) - 0.5) * 0.06)
                    + flutter * 30 * scale * depth
                y = size.height * (-0.15 + random(index, 5) * 0.1
                                   + t * (0.2 + random(index, 14) * 0.24) + 0.08 * t * t)
            } else {
                // Travel is proportional to the whole display, including
                // ultrawide screens; the small-piece scale only affects size.
                let originX = size.width * (side < 0 ? 0.015 : 0.985)
                let spread = -side * size.width * (0.12 + random(index, 4) * 0.97)
                x = originX + spread * (1 - exp(-t * 0.72)) / 0.72 + flutter * t * 20 * scale
                y = size.height * (1.02 - (0.96 + random(index, 5)) * t + 0.53 * t * t)
            }
            let width = (6 + random(index, 7) * 8) * scale * depth
            let height = (9 + random(index, 8) * 14) * scale * depth
            let color = colors[(index / 2) % colors.count]
            var piece = context
            piece.opacity = min(1, t / 0.04) * min(1, (life - t) / 0.4)
                * min(1, (Self.duration - elapsed) / 0.4) * (0.7 + depth * 0.2)
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(random(index, 9) * .pi * 2 + t * (random(index, 10) * 10 - 5)))
            piece.scaleBy(x: 0.18 + abs(cos(t * (4 + random(index, 11) * 5))) * 0.82, y: 1)
            let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
            let shape: Path
            switch index % 10 {
            case 0, 1: shape = Path(ellipseIn: rect)
            case 2, 3:
                var streamer = Path()
                streamer.move(to: CGPoint(x: -width / 2, y: -height))
                streamer.addCurve(to: CGPoint(x: width / 2, y: height),
                                  control1: CGPoint(x: width * 1.5, y: -height / 3),
                                  control2: CGPoint(x: -width * 1.5, y: height / 3))
                piece.stroke(streamer, with: .color(color),
                             style: StrokeStyle(lineWidth: 2.5 * scale * depth, lineCap: .round))
                continue
            case 4:
                var star = Path()
                for point in 0..<10 {
                    let angle = Double(point) * .pi / 5 - .pi / 2
                    let radius = width * (point.isMultiple(of: 2) ? 0.85 : 0.38)
                    let vertex = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                    if point == 0 { star.move(to: vertex) } else { star.addLine(to: vertex) }
                }
                star.closeSubpath()
                shape = star
            default: shape = Path(roundedRect: rect, cornerRadius: 1.5 * scale)
            }
            piece.fill(shape, with: .color(color))
        }
    }

    // Stable seeds keep particles synchronized across displays and reproducible
    // in documentation renders; there is no frame-to-frame random flicker.
    private func random(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index * 127 + salt * 311)) * 43758.5453
        return value - floor(value)
    }
}
