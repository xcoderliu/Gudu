import SwiftUI

/// Resolution-independent vector animation. Every frame is drawn from paths,
/// gradients and ellipses; no raster frames, web view or third-party runtime.
struct WaterScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rippleStaticAnimation) private var staticAnimation
    @State private var started = Date()
    var framesPerSecond = 30.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / framesPerSecond, paused: reduceMotion || staticAnimation)) { timeline in
            let time = reduceMotion || staticAnimation ? 5 : max(0, timeline.date.timeIntervalSince(started))
            Canvas { context, size in
                let side = min(size.width, size.height)
                context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
                context.scaleBy(x: side / 400, y: side / 400)
                drawScene(context: context, time: time)
            }
        }
        .accessibilityLabel("水滴落入杯中，清水缓缓上升，涟漪向四周散开")
        .accessibilityAddTraits(.isImage)
    }

    private func drawScene(context: GraphicsContext, time: Double) {
        let mint = Color(hex: 0xA5ECCD)
        let aqua = Color(hex: 0x55C9BE)
        let wave = sin(time * 1.4)

        // Soft atmospheric halo, still built from vector ellipses.
        var glow = context
        glow.addFilter(.blur(radius: 32))
        glow.fill(Path(ellipseIn: CGRect(x: 90, y: 103, width: 220, height: 220)),
                  with: .color(aqua.opacity(0.12)))

        for index in 0..<3 {
            let progress = (time * 0.18 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
            let width = 215 + 140 * progress
            let rect = CGRect(x: 200 - width / 2, y: 302 - 26 * progress,
                              width: width, height: 48 + 45 * progress)
            context.stroke(Path(ellipseIn: rect), with: .color(mint.opacity((1 - progress) * 0.23)), lineWidth: 1)
        }
        context.fill(Path(ellipseIn: CGRect(x: 130, y: 307, width: 140, height: 20)),
                     with: .color(.black.opacity(0.12)))

        let glass = glassPath()
        context.fill(glass, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.13), .white.opacity(0.025), .white.opacity(0.09)]),
            startPoint: CGPoint(x: 122, y: 160), endPoint: CGPoint(x: 279, y: 280)))

        var liquid = context
        liquid.clip(to: glass)
        let entry = min(time / 3.5, 1)
        let surface = 282 - 104 * entry + wave * 3
        for layer in 0..<3 {
            let offset = Double(layer) * 7
            let water = waterPath(surface: surface + offset, time: time, layer: layer)
            liquid.fill(water, with: .linearGradient(
                Gradient(colors: [mint.opacity(0.57 - Double(layer) * 0.07), aqua.opacity(0.45)]),
                startPoint: CGPoint(x: 200, y: surface), endPoint: CGPoint(x: 200, y: 330)))
        }
        var crest = Path()
        for x in stride(from: 110.0, through: 290.0, by: 2) {
            let y = surface + sin(x / 27 + time * 1.7) * 5
            if x == 110 { crest.move(to: CGPoint(x: x, y: y)) }
            else { crest.addLine(to: CGPoint(x: x, y: y)) }
        }
        liquid.stroke(crest, with: .color(mint.opacity(0.7)), lineWidth: 1.4)

        for index in 0..<8 {
            let speed = 0.09 + Double(index % 3) * 0.025
            let progress = (time * speed + Double(index) * 0.173).truncatingRemainder(dividingBy: 1)
            let x = 148 + Double(index) * 14 + sin(time + Double(index)) * 4
            let y = 309 - progress * 140
            let radius = 1.8 + Double(index % 3)
            liquid.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                          with: .color(.white.opacity((1 - progress) * 0.4)), lineWidth: 0.8)
        }

        context.stroke(glass, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.48), mint.opacity(0.17), .white.opacity(0.35)]),
            startPoint: CGPoint(x: 125, y: 110), endPoint: CGPoint(x: 275, y: 320)), lineWidth: 1.8)
        let rim = Path(ellipseIn: CGRect(x: 118, y: 98, width: 164, height: 26))
        context.fill(rim, with: .color(.white.opacity(0.035)))
        context.stroke(rim, with: .color(.white.opacity(0.38)), lineWidth: 1.5)

        var highlight = Path()
        highlight.move(to: CGPoint(x: 135, y: 139))
        highlight.addQuadCurve(to: CGPoint(x: 149, y: 290), control: CGPoint(x: 139, y: 236))
        context.stroke(highlight, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        var highlight2 = Path()
        highlight2.move(to: CGPoint(x: 269, y: 143))
        highlight2.addLine(to: CGPoint(x: 261, y: 230))
        context.stroke(highlight2, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        // A teardrop slowly breathes above the cup; smaller drops fall below it.
        var dropContext = context
        let dropY = 48 + sin(time * 1.3) * 5
        dropContext.translateBy(x: 200, y: dropY)
        let drop = dropPath(size: 28)
        dropContext.fill(drop, with: .linearGradient(
            Gradient(colors: [Color(hex: 0xD6F9D9), aqua]),
            startPoint: CGPoint(x: -10, y: -15), endPoint: CGPoint(x: 13, y: 18)))
        dropContext.fill(Path(ellipseIn: CGRect(x: -7, y: 0, width: 4, height: 7)),
                         with: .color(.white.opacity(0.65)))
        let falling = (time * 0.65).truncatingRemainder(dividingBy: 1)
        let fallSize = 3.5 * sin(falling * .pi)
        context.fill(Path(ellipseIn: CGRect(x: 200 - fallSize / 2, y: 72 + falling * 49,
                                           width: fallSize, height: fallSize * 1.8)),
                     with: .color(mint.opacity(0.75)))

        let particles: [(Double, Double, Double)] = [(88, 138, 3), (310, 173, 4), (105, 253, 2),
                                                   (293, 75, 2), (318, 281, 2.5), (73, 290, 1.7)]
        for (index, particle) in particles.enumerated() {
            let offset = sin(time * 0.8 + Double(index) * 1.8) * 7
            let opacity = 0.25 + (sin(time + Double(index)) + 1) * 0.15
            context.fill(Path(ellipseIn: CGRect(x: particle.0, y: particle.1 + offset,
                                               width: particle.2, height: particle.2)),
                         with: .color(mint.opacity(opacity)))
        }
        drawSparkle(context: context, center: CGPoint(x: 302, y: 125 + sin(time) * 4), radius: 6,
                    color: mint.opacity(0.65))
        drawSparkle(context: context, center: CGPoint(x: 93, y: 203 - sin(time * 0.8) * 5), radius: 4,
                    color: mint.opacity(0.4))
    }

    private func glassPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 118, y: 110))
        path.addQuadCurve(to: CGPoint(x: 137, y: 302), control: CGPoint(x: 128, y: 248))
        path.addQuadCurve(to: CGPoint(x: 155, y: 318), control: CGPoint(x: 140, y: 318))
        path.addQuadCurve(to: CGPoint(x: 245, y: 318), control: CGPoint(x: 200, y: 327))
        path.addQuadCurve(to: CGPoint(x: 263, y: 302), control: CGPoint(x: 260, y: 318))
        path.addQuadCurve(to: CGPoint(x: 282, y: 110), control: CGPoint(x: 272, y: 248))
        path.addQuadCurve(to: CGPoint(x: 118, y: 110), control: CGPoint(x: 200, y: 87))
        path.closeSubpath()
        return path
    }

    private func waterPath(surface: Double, time: Double, layer: Int) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 100, y: 340))
        path.addLine(to: CGPoint(x: 100, y: surface))
        for x in stride(from: 100.0, through: 300.0, by: 3) {
            let y = surface + sin(x / (27 + Double(layer) * 6) + time * (1.7 - Double(layer) * 0.35) + Double(layer)) * (5 + Double(layer))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: 300, y: 340))
        path.closeSubpath()
        return path
    }

    private func dropPath(size: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -size * 0.7))
        path.addCurve(to: CGPoint(x: 0, y: size * 0.65),
                      control1: CGPoint(x: size * 0.2, y: -size * 0.35),
                      control2: CGPoint(x: size, y: size * 0.45))
        path.addCurve(to: CGPoint(x: 0, y: -size * 0.7),
                      control1: CGPoint(x: -size, y: size * 0.45),
                      control2: CGPoint(x: -size * 0.2, y: -size * 0.35))
        path.closeSubpath()
        return path
    }

    private func drawSparkle(context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: center.x - radius, y: center.y))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: center)
        path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: center)
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: center)
        path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: center)
        context.fill(path, with: .color(color))
    }
}
