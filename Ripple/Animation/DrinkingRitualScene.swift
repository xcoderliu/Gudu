import RippleCore
import SwiftUI

/// A complete Lottie-style scene, drawn from native vector geometry:
/// approach the purifier, fill a cup, carry it, sip, lower it, and breathe out.
struct DrinkingRitualScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rippleStaticAnimation) private var staticAnimation
    let startedAt: Date
    var character: ReminderCharacter = .neutral
    var snapshotTime: TimeInterval? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || staticAnimation || snapshotTime != nil)) { timeline in
            let pose = DrinkingTimeline(elapsed: snapshotTime ?? timeline.date.timeIntervalSince(startedAt),
                                        still: snapshotTime == nil && (reduceMotion || staticAnimation))
            Canvas { context, size in
                let scale = min(size.width / 960, size.height / 440)
                context.translateBy(x: (size.width - 960 * scale) / 2, y: (size.height - 440 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                drawStage(context, pose: pose)
            }
        }
        .accessibilityLabel("人物在开放式厨房的直饮净水龙头下接水，拿起杯子喝水，放下后微笑舒气")
        .accessibilityAddTraits(.isImage)
    }

    private let cream = Color(hex: 0xE8EEDC)
    private let skin = Color(hex: 0xE9BB96)
    private let dark = Color(hex: 0x183D3B)

    private func drawStage(_ context: GraphicsContext, pose: DrinkingTimeline) {
        var scene = context
        scene.opacity = pose.opacity
        let t = pose.time
        // A gentle architectural arch frames the ritual without a bitmap backdrop.
        let arch = Path(roundedRect: CGRect(x: 124, y: 31, width: 712, height: 361),
                        cornerSize: CGSize(width: 175, height: 175))
        scene.fill(arch, with: .linearGradient(Gradient(colors: [Palette.mint.opacity(0.035), .clear]),
                                              startPoint: CGPoint(x: 480, y: 30), endPoint: CGPoint(x: 480, y: 390)))
        scene.stroke(arch, with: .color(Palette.mint.opacity(0.045)), lineWidth: 1)
        scene.fill(Path(ellipseIn: CGRect(x: 171, y: 365, width: 615, height: 35)),
                   with: .color(.black.opacity(0.12)))
        line(scene, from: CGPoint(x: 126, y: 386), to: CGPoint(x: 833, y: 386), color: Palette.mint.opacity(0.14), width: 1)
        drawPlant(scene, time: t)
        drawKitchen(scene, pose: pose)

        let body = DrinkingBodyPose(timeline: pose)
        drawPerson(scene, body: body, pose: pose)
        drawCup(scene, center: body.cupCenter, pose: pose)
        drawFingers(scene, body: body, pose: pose)

        // Water from the spout is above the glass, with tiny splash droplets.
        if pose.stream > 0 {
            var waterContext = scene
            waterContext.opacity = pose.stream
            let streamX = 284.0
            var stream = Path()
            stream.move(to: CGPoint(x: streamX, y: 215))
            stream.addCurve(to: CGPoint(x: streamX + sin(t * 14), y: 257),
                            control1: CGPoint(x: streamX - 1, y: 230), control2: CGPoint(x: streamX + 2, y: 240))
            waterContext.stroke(stream, with: .color(Palette.mint.opacity(0.8)), style: StrokeStyle(lineWidth: 3.7, lineCap: .round))
            for index in 0..<5 {
                let p = (t * 2 + Double(index) / 5).truncatingRemainder(dividingBy: 1)
                let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
                let point = CGPoint(x: streamX + direction * p * 15, y: 264 - sin(p * .pi) * 9)
                waterContext.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 2.3, height: 3.7)),
                                  with: .color(Palette.mint.opacity(1 - p)))
            }
        }
        if pose.relaxed > 0 { drawRelief(scene, x: Double(body.positionX), pose: pose) }
    }

    private func drawKitchen(_ context: GraphicsContext, pose: DrinkingTimeline) {
        // An open kitchen: backsplash, floating shelf, counter and sink. The
        // filtration unit sits below the counter; only its slim drinking tap shows.
        let backsplash = Path(roundedRect: CGRect(x: 146, y: 79, width: 288, height: 230),
                              cornerSize: CGSize(width: 18, height: 18))
        context.fill(backsplash, with: .linearGradient(Gradient(colors: [cream.opacity(0.07), cream.opacity(0.015)]),
                                                     startPoint: CGPoint(x: 280, y: 80), endPoint: CGPoint(x: 280, y: 310)))
        for y in [134.0, 190, 246] {
            line(context, from: CGPoint(x: 150, y: y), to: CGPoint(x: 430, y: y), color: cream.opacity(0.045), width: 1)
        }
        for (x, top) in [(220.0, 80.0), (360, 80), (290, 134), (220, 190), (360, 190), (290, 246)] {
            line(context, from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: top + 54), color: cream.opacity(0.04), width: 1)
        }
        context.fill(Path(roundedRect: CGRect(x: 171, y: 94, width: 218, height: 8), cornerSize: CGSize(width: 3, height: 3)),
                     with: .color(Color(hex: 0xB6A589).opacity(0.7)))
        // A ceramic jar and a little herb on the shelf establish the kitchen.
        context.fill(Path(roundedRect: CGRect(x: 326, y: 60, width: 28, height: 34), cornerSize: CGSize(width: 5, height: 5)),
                     with: .color(cream.opacity(0.65)))
        context.fill(Path(roundedRect: CGRect(x: 324, y: 57, width: 32, height: 6), cornerSize: CGSize(width: 2, height: 2)),
                     with: .color(Color(hex: 0xB6A589)))
        context.fill(Path(roundedRect: CGRect(x: 365, y: 77, width: 18, height: 17), cornerSize: CGSize(width: 3, height: 3)),
                     with: .color(cream.opacity(0.45)))
        line(context, from: CGPoint(x: 374, y: 78), to: CGPoint(x: 373, y: 57), color: Palette.mint.opacity(0.5), width: 2)
        context.fill(Path(ellipseIn: CGRect(x: 362, y: 54, width: 12, height: 18)), with: .color(Palette.mint.opacity(0.4)))
        context.fill(Path(ellipseIn: CGRect(x: 374, y: 47, width: 10, height: 18)), with: .color(Palette.mint.opacity(0.5)))

        let cabinets = Path(roundedRect: CGRect(x: 151, y: 343, width: 286, height: 43), cornerSize: CGSize(width: 4, height: 4))
        context.fill(cabinets, with: .linearGradient(Gradient(colors: [Color(hex: 0x96B99F), Color(hex: 0x6B9380)]),
                                                   startPoint: CGPoint(x: 150, y: 340), endPoint: CGPoint(x: 440, y: 390)))
        line(context, from: CGPoint(x: 294, y: 350), to: CGPoint(x: 294, y: 383), color: dark.opacity(0.17), width: 1)
        for x in [275.0, 312] {
            line(context, from: CGPoint(x: x, y: 356), to: CGPoint(x: x, y: 368), color: cream.opacity(0.7), width: 2)
        }
        context.fill(Path(roundedRect: CGRect(x: 139, y: 332, width: 310, height: 14), cornerSize: CGSize(width: 5, height: 5)),
                     with: .color(cream.opacity(0.9)))
        context.fill(Path(ellipseIn: CGRect(x: 239, y: 324, width: 105, height: 13)), with: .color(dark.opacity(0.62)))
        context.stroke(Path(ellipseIn: CGRect(x: 235, y: 321, width: 113, height: 17)), with: .color(cream.opacity(0.6)), lineWidth: 1.5)

        var faucet = Path()
        faucet.move(to: CGPoint(x: 218, y: 326))
        faucet.addLine(to: CGPoint(x: 218, y: 173))
        faucet.addCurve(to: CGPoint(x: 284, y: 173), control1: CGPoint(x: 218, y: 126), control2: CGPoint(x: 284, y: 126))
        faucet.addLine(to: CGPoint(x: 284, y: 212))
        context.stroke(faucet, with: .linearGradient(Gradient(colors: [Color(hex: 0x7FACA0), cream, Color(hex: 0x95BEB0)]),
                                                    startPoint: CGPoint(x: 208, y: 160), endPoint: CGPoint(x: 290, y: 270)),
                       style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        context.fill(Path(ellipseIn: CGRect(x: 204, y: 322, width: 28, height: 9)), with: .color(cream.opacity(0.9)))
        context.fill(Path(ellipseIn: CGRect(x: 279, y: 210, width: 10, height: 5)), with: .color(dark))
        line(context, from: CGPoint(x: 217, y: 295), to: CGPoint(x: 199, y: 280 - pose.stream * 9), color: cream.opacity(0.85), width: 5)
        context.fill(Path(ellipseIn: CGRect(x: 213, y: 304, width: 5, height: 5)),
                     with: .color(pose.stream > 0 ? Palette.mint : cream.opacity(0.4)))
        label(context, "FILTERED · 净水直饮", at: CGPoint(x: 290, y: 414), size: 9, color: Palette.mint.opacity(0.4))
    }

    private func drawPerson(_ context: GraphicsContext, body: DrinkingBodyPose, pose: DrinkingTimeline) {
        let x = Double(body.positionX)
        let sway = Double(body.sway)
        let leftFoot = Double(body.stride)
        let sweater: Color = switch character {
        case .neutral: Color(hex: 0x93BFA5)
        case .woman: Color(hex: 0xC0B7D5)
        case .man: Color(hex: 0x91B4C4)
        }
        let pants = Color(hex: 0x3A5D51)

        context.fill(Path(ellipseIn: CGRect(x: x - 58, y: 373, width: 120, height: 15)), with: .color(.black.opacity(0.12)))
        line(context, from: CGPoint(x: x - 20, y: 307), to: CGPoint(x: x - 24 + leftFoot, y: 371), color: pants, width: 29)
        line(context, from: CGPoint(x: x + 18, y: 307), to: CGPoint(x: x + 25 - leftFoot, y: 371), color: pants, width: 29)
        context.fill(Path(roundedRect: CGRect(x: x - 47 + leftFoot, y: 367, width: 43, height: 15), cornerSize: CGSize(width: 7, height: 7)),
                     with: .color(cream))
        context.fill(Path(roundedRect: CGRect(x: x + 6 - leftFoot, y: 367, width: 43, height: 15), cornerSize: CGSize(width: 7, height: 7)),
                     with: .color(cream))

        // Relaxed far arm, behind the torso.
        var farArm = Path()
        farArm.move(to: CGPoint(x: x + 37, y: 220 + sway))
        farArm.addQuadCurve(to: CGPoint(x: x + 54, y: 270), control: CGPoint(x: x + 59, y: 233))
        farArm.addQuadCurve(to: CGPoint(x: x + 20 - pose.relaxed * 9, y: 295 - pose.relaxed * 10),
                            control: CGPoint(x: x + 51, y: 292))
        context.stroke(farArm, with: .color(sweater.opacity(0.85)), style: StrokeStyle(lineWidth: 23, lineCap: .round, lineJoin: .round))
        context.fill(Path(ellipseIn: CGRect(x: x + 8 - pose.relaxed * 9, y: 287 - pose.relaxed * 10, width: 22, height: 15)),
                     with: .color(skin))

        // Neck and a soft oversized sweater.
        context.fill(Path(roundedRect: CGRect(x: x - 12, y: 174 + sway, width: 26, height: 34), cornerSize: CGSize(width: 8, height: 8)),
                     with: .color(skin))
        var torso = Path()
        torso.move(to: CGPoint(x: x - 16, y: 197 + sway))
        torso.addQuadCurve(to: CGPoint(x: x - 47, y: 218 + sway), control: CGPoint(x: x - 40, y: 197 + sway))
        torso.addLine(to: CGPoint(x: x - 42, y: 310))
        torso.addQuadCurve(to: CGPoint(x: x + 42, y: 310), control: CGPoint(x: x, y: 323))
        torso.addLine(to: CGPoint(x: x + 47, y: 218 + sway))
        torso.addQuadCurve(to: CGPoint(x: x + 15, y: 197 + sway), control: CGPoint(x: x + 40, y: 197 + sway))
        torso.addQuadCurve(to: CGPoint(x: x - 16, y: 197 + sway), control: CGPoint(x: x, y: 213 + sway))
        context.fill(torso, with: .linearGradient(Gradient(colors: [sweater, sweater.opacity(0.8)]),
                                                startPoint: CGPoint(x: x - 40, y: 200), endPoint: CGPoint(x: x + 40, y: 320)))
        line(context, from: CGPoint(x: x - 32, y: 304), to: CGPoint(x: x + 33, y: 304), color: dark.opacity(0.08), width: 2)
        context.fill(Path(roundedRect: CGRect(x: x + 6, y: 236, width: 21, height: 22), cornerSize: CGSize(width: 3, height: 3)),
                     with: .color(cream.opacity(0.18)))

        // Head tilts back slightly with the sip, then softens into a smile.
        var head = context
        head.translateBy(x: x, y: 145 + sway)
        head.rotate(by: .degrees(-pose.tilt * 9 + pose.relaxed * 4))
        head.fill(Path(ellipseIn: CGRect(x: -33, y: -46, width: 68, height: 79)), with: .color(dark))
        if character == .woman {
            // Longer hair behind the face; the shared pose and actions stay equal.
            head.fill(Path(ellipseIn: CGRect(x: 22, y: -10, width: 34, height: 72)), with: .color(dark))
        }
        head.fill(Path(ellipseIn: CGRect(x: -30, y: -35, width: 60, height: 77)), with: .color(skin))
        head.fill(Path(ellipseIn: CGRect(x: 23, y: 0, width: 14, height: 20)), with: .color(skin))
        var hair = Path()
        hair.move(to: CGPoint(x: -33, y: -13))
        hair.addCurve(to: CGPoint(x: 31, y: -5), control1: CGPoint(x: -48, y: -68), control2: CGPoint(x: 48, y: -69))
        hair.addLine(to: CGPoint(x: 26, y: 11))
        hair.addQuadCurve(to: CGPoint(x: 17, y: -17), control: CGPoint(x: 13, y: 1))
        hair.addQuadCurve(to: CGPoint(x: -18, y: -21), control: CGPoint(x: -8, y: -8))
        hair.addQuadCurve(to: CGPoint(x: -33, y: -13), control: CGPoint(x: -23, y: -12))
        head.fill(hair, with: .color(dark))
        if character == .man {
            var crop = Path()
            crop.move(to: CGPoint(x: -34, y: -23))
            crop.addLine(to: CGPoint(x: -26, y: -43))
            crop.addQuadCurve(to: CGPoint(x: 28, y: -34), control: CGPoint(x: 8, y: -60))
            crop.addLine(to: CGPoint(x: 31, y: -6))
            crop.addQuadCurve(to: CGPoint(x: -34, y: -23), control: CGPoint(x: 10, y: -38))
            head.fill(crop, with: .color(dark))
        }
        line(head, from: CGPoint(x: -19, y: -38), to: CGPoint(x: 2, y: -43), color: cream.opacity(0.11), width: 3)
        head.fill(Path(ellipseIn: CGRect(x: -36, y: 0, width: 11, height: 14)), with: .color(skin))
        let eyesClosed = pose.tilt > 0.15 || pose.relaxed > 0.1
        if eyesClosed {
            var eye = Path()
            eye.move(to: CGPoint(x: -20, y: -3))
            eye.addQuadCurve(to: CGPoint(x: -9, y: -3), control: CGPoint(x: -14, y: 2))
            head.stroke(eye, with: .color(dark.opacity(0.7)), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
        } else {
            head.fill(Path(ellipseIn: CGRect(x: -20, y: -4, width: 4, height: 5)), with: .color(dark.opacity(0.8)))
        }
        head.fill(Path(ellipseIn: CGRect(x: -13, y: 9, width: 14, height: 8)), with: .color(Color(hex: 0xD58A75).opacity(0.4 + pose.relaxed * 0.2)))
        var mouth = Path()
        mouth.move(to: CGPoint(x: -25, y: 17))
        mouth.addQuadCurve(to: CGPoint(x: -11, y: 19), control: CGPoint(x: -19, y: 19 + pose.relaxed * 8))
        head.stroke(mouth, with: .color(dark.opacity(0.65)), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

        line(context, from: body.shoulder, to: body.elbow, color: sweater, width: 26)
        line(context, from: body.elbow, to: body.wrist, color: skin, width: 17)
        context.fill(Path(ellipseIn: CGRect(x: body.wrist.x - 9, y: body.wrist.y - 8, width: 18, height: 16)), with: .color(skin))
    }

    private func drawFingers(_ context: GraphicsContext, body: DrinkingBodyPose, pose: DrinkingTimeline) {
        guard pose.grasp > 0 else { return }
        var hand = context
        hand.opacity *= pose.grasp
        hand.translateBy(x: body.cupCenter.x, y: body.cupCenter.y)
        hand.rotate(by: .degrees(pose.tilt * 49))
        // The fingers wrap over the rim-side edge; the wrist behind the glass
        // and these foreground fingers stay attached as the glass rotates.
        for index in 0..<3 {
            let y = CGFloat(3 + index * 4)
            line(hand, from: CGPoint(x: 19, y: y), to: CGPoint(x: 29, y: y + 1), color: skin, width: 3.4)
        }
    }

    private func drawCup(_ context: GraphicsContext, center: CGPoint, pose: DrinkingTimeline) {
        var glass = context
        glass.opacity *= pose.arrival
        glass.translateBy(x: center.x, y: center.y)
        glass.rotate(by: .degrees(pose.tilt * 49))
        var shape = Path()
        shape.move(to: CGPoint(x: -27, y: -39))
        shape.addLine(to: CGPoint(x: -22, y: 37))
        shape.addQuadCurve(to: CGPoint(x: 22, y: 37), control: CGPoint(x: 0, y: 45))
        shape.addLine(to: CGPoint(x: 27, y: -39))
        shape.closeSubpath()
        glass.fill(shape, with: .color(.white.opacity(0.09)))
        var liquid = glass
        liquid.clip(to: shape)
        let surface = 34 - 63 * pose.water
        var water = Path()
        water.move(to: CGPoint(x: -35, y: 48))
        for x in stride(from: -35.0, through: 35, by: 2) {
            water.addLine(to: CGPoint(x: x, y: surface + sin(x / 10 + pose.time * 4) * 1.8 - x * pose.tilt * 0.42))
        }
        water.addLine(to: CGPoint(x: 35, y: 48))
        water.closeSubpath()
        liquid.fill(water, with: .linearGradient(Gradient(colors: [Palette.mint.opacity(0.85), Color(hex: 0x63BEB1).opacity(0.7)]),
                                                startPoint: CGPoint(x: 0, y: -40), endPoint: CGPoint(x: 0, y: 40)))
        glass.stroke(shape, with: .color(cream.opacity(0.7)), lineWidth: 1.5)
        glass.stroke(Path(ellipseIn: CGRect(x: -27, y: -44, width: 54, height: 10)), with: .color(cream.opacity(0.8)), lineWidth: 1.4)
        line(glass, from: CGPoint(x: -19, y: -26), to: CGPoint(x: -15, y: 28), color: .white.opacity(0.35), width: 2)
    }

    private func drawRelief(_ context: GraphicsContext, x: Double, pose: DrinkingTimeline) {
        var relief = context
        relief.opacity *= pose.relaxed
        let bubble = Path(roundedRect: CGRect(x: x - 42, y: 31, width: 155, height: 40), cornerSize: CGSize(width: 17, height: 17))
        relief.fill(bubble, with: .color(Palette.mint.opacity(0.12)))
        var tip = Path()
        tip.move(to: CGPoint(x: x - 4, y: 69)); tip.addLine(to: CGPoint(x: x + 5, y: 80)); tip.addLine(to: CGPoint(x: x + 12, y: 69))
        relief.fill(tip, with: .color(Palette.mint.opacity(0.12)))
        label(relief, "啊，舒服了～", at: CGPoint(x: x + 35, y: 51), size: 15, color: Palette.mint.opacity(0.9))
        for index in 0..<4 {
            let angle = Double(index) * 0.68 - 1.7
            let distance = 82.0 + sin(pose.time * 2 + Double(index)) * 4
            let origin = CGPoint(x: x + cos(angle) * distance, y: 145 + sin(angle) * distance)
            sparkle(relief, at: origin, radius: index.isMultiple(of: 2) ? 5 : 3, opacity: 0.6)
        }
        let breath = sin(min(max((pose.time - 10.8) / 2.3, 0), 1) * .pi)
        if breath > 0 {
            var path = Path()
            path.move(to: CGPoint(x: x - 37, y: 169))
            path.addCurve(to: CGPoint(x: x - 92, y: 149), control1: CGPoint(x: x - 78, y: 186), control2: CGPoint(x: x - 103, y: 167))
            relief.stroke(path, with: .color(cream.opacity(breath * 0.4)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    private func drawPlant(_ context: GraphicsContext, time: Double) {
        let baseX = 804.0
        context.fill(Path(roundedRect: CGRect(x: baseX - 23, y: 336, width: 47, height: 48), cornerSize: CGSize(width: 9, height: 9)),
                     with: .color(Color(hex: 0xB8A783).opacity(0.6)))
        for index in 0..<3 {
            let x = baseX + Double(index - 1) * 17
            let y = 274 + Double(index % 2) * 18
            var stem = Path()
            stem.move(to: CGPoint(x: baseX, y: 340))
            stem.addQuadCurve(to: CGPoint(x: x + sin(time * 0.8) * 2, y: y), control: CGPoint(x: x, y: 310))
            context.stroke(stem, with: .color(Palette.mint.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            var leaf = context
            leaf.translateBy(x: x, y: y + 5)
            leaf.rotate(by: .degrees(Double(index - 1) * 30))
            leaf.fill(Path(ellipseIn: CGRect(x: -9, y: -24, width: 18, height: 37)), with: .color(Palette.mint.opacity(0.28)))
        }
    }

    private func line(_ context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: CGFloat) {
        var path = Path(); path.move(to: from); path.addLine(to: to)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func label(_ context: GraphicsContext, _ text: String, at point: CGPoint, size: CGFloat, color: Color) {
        context.draw(Text(text).font(.system(size: size, weight: .medium, design: .rounded)).foregroundColor(color), at: point)
    }

    private func sparkle(_ context: GraphicsContext, at point: CGPoint, radius: Double, opacity: Double) {
        var star = Path()
        star.move(to: CGPoint(x: point.x - radius, y: point.y))
        star.addQuadCurve(to: CGPoint(x: point.x, y: point.y - radius), control: point)
        star.addQuadCurve(to: CGPoint(x: point.x + radius, y: point.y), control: point)
        star.addQuadCurve(to: CGPoint(x: point.x, y: point.y + radius), control: point)
        star.addQuadCurve(to: CGPoint(x: point.x - radius, y: point.y), control: point)
        context.fill(star, with: .color(Palette.mint.opacity(opacity)))
    }
}
