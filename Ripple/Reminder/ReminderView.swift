import SwiftUI
import RippleCore

struct ReminderView: View {
    @ObservedObject var session: ReminderSession
    let onAction: (ReminderAction) -> Void

    var body: some View {
        GeometryReader { geometry in
            let scale = min(1.25, min(geometry.size.width / 1000, geometry.size.height / 830))
            ZStack {
                OceanBackdrop()
                VStack(spacing: 0) {
                    HStack(spacing: 9) {
                        Image(systemName: "drop.fill").font(.system(size: 16))
                        Text("澄水").font(.system(size: 16, weight: .medium))
                        Text("R I P P L E").font(.system(size: 10, weight: .medium)).opacity(0.45)
                        Spacer()
                        if session.isPreview {
                            Text("动画预览 · 不计入饮水记录")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                                .padding(.trailing, 18)
                        }
                        Button { onAction(.dismiss) } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.07), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("关闭提醒，Escape")
                    }
                    .foregroundStyle(Palette.mint)
                    .padding(.horizontal, 40).padding(.top, 28)
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        ZStack {
                            DrinkingRitualScene(startedAt: session.startedAt, character: session.character).frame(width: 800, height: 360)
                                .opacity(session.completed ? 0.15 : 1)
                            if session.completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 45, weight: .light))
                                    .foregroundStyle(Palette.mint)
                                    .frame(width: 100, height: 100)
                                    .background(Palette.mint.opacity(0.09), in: Circle())
                                    .overlay(Circle().stroke(Palette.mint.opacity(0.3), lineWidth: 1))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.bottom, 5)
                        Text(session.completed ? (session.isPreview ? "让每一杯，都有回响。" : "很好，又照顾了自己一点。") : "给自己，一杯水的时间。")
                            .font(.system(size: 39, weight: .light, design: .rounded))
                            .tracking(3).foregroundStyle(Color(hex: 0xEAF5E9))
                        Group {
                            if session.completed {
                                Text(session.isPreview ? "准备好了，就把这份温柔带回日常。" : "这一杯，已记入今天的小小成就。")
                            } else { RitualCaption(startedAt: session.startedAt) }
                        }
                            .font(.system(size: 14)).tracking(1)
                            .foregroundStyle(Palette.mint.opacity(0.52))
                            .padding(.top, 17)
                        HStack(spacing: 14) {
                            Button { onAction(.drank) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark")
                                    Text(session.isPreview ? "完成预览" : "我喝好了")
                                    if !session.isPreview {
                                        Text("+\(session.servingML) mL").opacity(0.55)
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 27).frame(height: 49)
                                .foregroundStyle(Palette.ocean)
                                .background(Palette.mint, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Button { onAction(session.isPreview ? .dismiss : .snooze) } label: {
                                Text(session.isPreview ? "返回" : "5 分钟后提醒")
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 24).frame(height: 49)
                                    .foregroundStyle(Palette.mint.opacity(0.75))
                                    .overlay(Capsule().stroke(Palette.mint.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 34)
                        .opacity(session.completed ? 0 : 1)
                        .disabled(session.completed)
                    }
                    .scaleEffect(scale)
                    .frame(height: 625 * scale)
                    Spacer(minLength: 0)
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        HStack(spacing: 8) {
                            Text("ESC 关闭")
                            Text("·")
                            Text("↵ \(session.isPreview ? "完成预览" : "记一杯")")
                            if let deadline = session.deadline {
                                Text("·")
                                Text("\(max(0, Int(ceil(deadline.timeIntervalSince(timeline.date))))) 秒后轻轻退场")
                                    .monospacedDigit()
                            }
                        }
                        .font(.system(size: 10)).tracking(0.6)
                        .foregroundStyle(Palette.mint.opacity(0.35))
                    }
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct RitualCaption: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rippleStaticAnimation) private var staticAnimation
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 0.3)) { timeline in
            let phase = DrinkingTimeline(elapsed: timeline.date.timeIntervalSince(startedAt),
                                          still: reduceMotion || staticAnimation).phase
            Text(caption(phase))
        }
    }

    private func caption(_ phase: DrinkingTimeline.Phase) -> String {
        switch phase {
        case .arrive, .fill: "接一杯清水，让身体也慢慢呼吸。"
        case .carry, .drink: "咕嘟咕嘟，把忙碌轻轻放一放。"
        case .relax: "啊，舒服了。再忙，也记得照顾自己。"
        }
    }
}

private struct OceanBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rippleStaticAnimation) private var staticAnimation
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || staticAnimation)) { timeline in
            let time = reduceMotion || staticAnimation ? 0 : timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x0B292B), Color(hex: 0x124340), Color(hex: 0x0C3232)]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                context.fill(Path(ellipseIn: CGRect(x: size.width * 0.1, y: -size.height * 0.2,
                                                   width: size.width * 0.8, height: size.height * 1.2)),
                             with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.065), .clear]),
                                                   center: CGPoint(x: size.width / 2, y: size.height * 0.36),
                                                   startRadius: 0, endRadius: size.height * 0.6))
                for layer in 0..<4 {
                    var path = Path()
                    let level = size.height * (0.80 + Double(layer) * 0.055)
                    path.move(to: CGPoint(x: 0, y: size.height))
                    for x in stride(from: 0.0, through: size.width + 8, by: 8) {
                        let y = level + sin(x / (size.width * 0.24) + time * 0.18 + Double(layer) * 1.3) * 35
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(Palette.mint.opacity(0.013 + Double(layer) * 0.005)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
