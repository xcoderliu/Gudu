import AppKit
import SwiftUI
import GuduCore

/// Render the actual SwiftUI views with isolated sample data. This never reads
/// screen pixels, requests recording permission, or modifies real user defaults.
@main
struct PreviewRenderer {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "local.gudu.documentation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let sampleDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
        let model = AppModel(defaults: defaults, clock: { sampleDate }, startsTimer: false)
        for _ in 0..<3 { model.recordDrink() }

        func export<Content: View>(_ view: Content, size: NSSize, name: String) throws {
            let hosting = NSHostingView(rootView: view
                .environment(\.guduStaticAnimation, true)
                .environment(\.locale, Locale(identifier: "zh_CN")))
            // Native controls and ScrollView need an AppKit backing hierarchy;
            // ImageRenderer alone cannot render them. This window stays hidden.
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            hosting.setFrameSize(size)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            hosting.displayIfNeeded()
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
                throw NSError(domain: "GuduPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(name)"])
            }
            bitmap.size = size
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "GuduPreview", code: 2)
            }
            try data.write(to: directory.appendingPathComponent(name))
            window.close()
            print("Rendered \(name)")
        }

        try export(DashboardView(model: model).frame(width: 1060, height: 820),
                   size: NSSize(width: 1060, height: 820), name: "dashboard.png")
        try export(PreparationBubbleView(minutes: 5, onDismiss: {}).frame(width: 340, height: 100),
                   size: NSSize(width: 340, height: 100), name: "preparation.png")
        let session = ReminderSession(preview: false, servingML: 250, seconds: 0)
        try export(ReminderView(session: session, onAction: { _ in }).frame(width: 1440, height: 900),
                   size: NSSize(width: 1440, height: 900), name: "reminder.png")
        model.settings.weekdays = ReminderWeekday.workdays
        try export(SettingsView(model: model).padding(30).frame(width: 800, height: 1900, alignment: .top)
            .background(Palette.background).preferredColorScheme(.light),
                   size: NSSize(width: 800, height: 1900), name: "settings.png")
        let verification = ReminderSession(preview: true, servingML: 250, seconds: 30, requiresVerification: true)
        try export(ReminderView(session: verification, onAction: { _ in }).frame(width: 1440, height: 900),
                   size: NSSize(width: 1440, height: 900), name: "camera-verification.png")
        let fallback = ReminderSession(preview: false, servingML: 250, seconds: 0, requiresVerification: true)
        fallback.camera.reportUnavailable("离线示例：摄像头暂时不可用。")
        try export(ReminderView(session: fallback, onAction: { _ in }).frame(width: 1440, height: 900),
                   size: NSSize(width: 1440, height: 900), name: "camera-fallback.png")
        let diagnostics = CupCameraDiagnostics(crops: [
            CupCropClassification(kind: .body, vesselConfidence: 0.11, dominantIdentifier: "person", dominantConfidence: 0.58),
            CupCropClassification(kind: .rim, vesselConfidence: 0.16, dominantIdentifier: "cup", dominantConfidence: 0.16),
            CupCropClassification(kind: .tilted, vesselConfidence: 0.09, dominantIdentifier: "cup", dominantConfidence: 0.09)
        ], hasHandNearMouth: true)
        let diagnosticsCard = VStack(alignment: .leading, spacing: 12) {
            Text("识别测试 · 杯具线索").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.mint)
            CameraDiagnosticsView(diagnostics: diagnostics)
            Text("离线示例分数，不代表实际识别准确率，不含摄像头画面。")
                .font(.system(size: 10)).foregroundStyle(Palette.mint.opacity(0.45))
        }.padding(22).frame(width: 620, height: 132, alignment: .leading).background(Palette.ocean)
        try export(diagnosticsCard, size: NSSize(width: 620, height: 132), name: "camera-diagnostics.png")
        let phases: [(String, Double)] = [("接一杯净水", 4.6), ("慢慢喝一口", 8.2), ("放松地舒气", 11.7)]
        let mascot = HStack(spacing: 0) {
            ForEach(phases.indices, id: \.self) { index in
                VStack(spacing: 8) {
                    DrinkingRitualScene(startedAt: .now, snapshotTime: phases[index].1)
                        .frame(width: 440, height: 240)
                    Text(phases[index].0)
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.mint.opacity(0.85))
                }
            }
        }
        .padding(25).background(Palette.ocean)
        try export(mascot, size: NSSize(width: 1370, height: 320), name: "mascot-poses.png")
        try export(GuduHero(), size: NSSize(width: 1600, height: 900), name: "gudu-hero.png")
        try export(GuduFeatures(), size: NSSize(width: 1440, height: 960), name: "gudu-features.png")
    }
}

/// Promotional artwork uses the actual vector scene, never camera footage.
private struct GuduHero: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0C2929), Color(hex: 0x185D50)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Palette.mint.opacity(0.045)).frame(width: 900, height: 900).offset(x: 590, y: -170)
            Circle().stroke(Palette.mint.opacity(0.07), lineWidth: 1).frame(width: 1120, height: 1120).offset(x: 590, y: -170)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "drop.fill").font(.system(size: 25)).foregroundStyle(Palette.mint)
                    Text("咕嘟").font(.system(size: 30, weight: .semibold)).tracking(3)
                    Text("G U D U").font(.system(size: 12, weight: .medium)).tracking(3).opacity(0.5)
                    Spacer()
                    Text("A LITTLE SIP. A LITTLE PAUSE.").font(.system(size: 11, weight: .medium)).tracking(2).opacity(0.45)
                }
                Spacer()
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 25) {
                        Text("给自己，\n一杯水的时间。").font(.system(size: 70, weight: .light)).tracking(3).lineSpacing(13)
                        Text("好好工作，也好好喝水。")
                            .font(.system(size: 22)).tracking(2).foregroundStyle(Palette.mint.opacity(0.7))
                        HStack(spacing: 10) {
                            pill("原生 macOS", "apple.logo")
                            pill("矢量动画", "sparkles")
                            pill("完全离线", "lock.shield")
                        }.padding(.top, 17)
                    }.frame(width: 660, alignment: .leading)
                    DrinkingRitualScene(startedAt: .now, snapshotTime: 8.2)
                        .frame(width: 780, height: 470).offset(x: -5, y: 10)
                }
                Spacer()
                HStack {
                    Text("轻轻提醒 · 每周节奏 · 多屏陪伴").font(.system(size: 15)).tracking(1.5).opacity(0.55)
                    Spacer()
                    Text("开源 / MIT     macOS 14+").font(.system(size: 12, weight: .medium)).tracking(1).opacity(0.45)
                }
            }.padding(80).frame(width: 1600, height: 900)
        }.foregroundStyle(Color(hex: 0xEAF5E9)).frame(width: 1600, height: 900)
    }
    private func pill(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Palette.mint.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Palette.mint.opacity(0.14), lineWidth: 1))
    }
}

private struct GuduFeatures: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(alignment: .firstTextBaseline) {
                Text("把喝水，变成一次小小的休息。").font(.system(size: 38, weight: .light)).tracking(2)
                Spacer()
                Text("咕嘟 / GUDU").font(.system(size: 12, weight: .medium)).tracking(2).foregroundStyle(Palette.accent)
            }
            HStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("接一杯水，再慢慢喝一口。").font(.system(size: 25, weight: .medium))
                    Text("全屏矢量动画 · 可选喝水音效 · 完成后庆典撒花")
                        .font(.system(size: 14)).foregroundStyle(Palette.secondary)
                    DrinkingRitualScene(startedAt: .now, snapshotTime: 8.2)
                        .frame(width: 820, height: 355)
                        .background(Palette.ocean, in: RoundedRectangle(cornerRadius: 18))
                }.padding(28).background(.white, in: RoundedRectangle(cornerRadius: 24))
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 34, weight: .light)).foregroundStyle(Palette.accent)
                    Text("嘴边举杯，\n轻轻完成。").font(.system(size: 30, weight: .light)).lineSpacing(7)
                    Text("可选本机摄像头识别\n画面不保存、不上传")
                        .font(.system(size: 16)).lineSpacing(8).foregroundStyle(Palette.secondary)
                    Spacer()
                    Text("新安装默认开启，可在设置关闭。\n不可用时支持手动确认。\n判断嘴边杯具，不能确认实际吞咽。")
                        .font(.system(size: 12)).lineSpacing(5).foregroundStyle(Palette.secondary)
                }.padding(32).frame(maxWidth: .infinity, alignment: .leading).frame(height: 434)
                    .background(Color(hex: 0xE5F1E9), in: RoundedRectangle(cornerRadius: 24))
            }
            HStack(spacing: 22) {
                tile("clock", "按你的节奏", "间隔、时段、每周提醒日\n都由你自己决定。")
                tile("display.2", "跟随工作屏幕", "鼠标在哪块屏幕，提醒就在哪。\n也能选择所有屏幕。")
                tile("moon.zzz", "回来，再提醒", "错过后缓冲 30 秒补一次。\n距正常提醒 ≤ 5 分钟则跳过。")
            }
            HStack {
                Text("没有账号，没有广告。留一点温柔给自己。")
                Spacer()
                Text("原生 SwiftUI / AppKit · MIT 开源")
            }.font(.system(size: 13)).foregroundStyle(Palette.secondary)
        }.padding(58).frame(width: 1440, height: 960).background(Palette.background).foregroundStyle(Palette.ink)
    }
    private func tile(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: symbol).font(.system(size: 27, weight: .light)).foregroundStyle(Palette.accent)
            Text(title).font(.system(size: 22, weight: .medium))
            Text(detail).font(.system(size: 14)).lineSpacing(7).foregroundStyle(Palette.secondary)
        }.padding(28).frame(maxWidth: .infinity, alignment: .leading).frame(height: 225)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }
}
