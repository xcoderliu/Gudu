import AppKit
import SwiftUI
import RippleCore

/// Render the actual SwiftUI views with isolated sample data. This never reads
/// screen pixels, requests recording permission, or modifies real user defaults.
@main
struct PreviewRenderer {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "local.ripple.documentation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        for _ in 0..<3 { model.recordDrink() }

        func export<Content: View>(_ view: Content, size: NSSize, name: String) throws {
            let hosting = NSHostingView(rootView: view
                .environment(\.rippleStaticAnimation, true)
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
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                throw NSError(domain: "RipplePreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(name)"])
            }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "RipplePreview", code: 2)
            }
            try data.write(to: directory.appendingPathComponent(name))
            window.close()
            print("Rendered \(name)")
        }

        try export(DashboardView(model: model).frame(width: 1060, height: 820),
                   size: NSSize(width: 1060, height: 820), name: "dashboard.png")
        let session = ReminderSession(preview: false, servingML: 250, seconds: 0)
        try export(ReminderView(session: session, onAction: { _ in }).frame(width: 1440, height: 900),
                   size: NSSize(width: 1440, height: 900), name: "reminder.png")
        try export(SettingsView(model: model).padding(30).frame(width: 800)
            .background(Palette.background).preferredColorScheme(.light),
                   size: NSSize(width: 800, height: 1440), name: "settings.png")
        let characters = HStack(spacing: 0) {
            ForEach(ReminderCharacter.allCases) { character in
                VStack(spacing: 8) {
                    DrinkingRitualScene(startedAt: .now, character: character,
                                        snapshotTime: character == .neutral ? 4 : character == .woman ? 8.2 : 11.7)
                        .frame(width: 440, height: 240)
                    Text(character == .neutral ? "中性 · 接一杯净水" : character == .woman ? "女性 · 慢慢喝一口" : "男性 · 放松地舒气")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.mint.opacity(0.85))
                }
            }
        }
        .padding(25).background(Palette.ocean)
        try export(characters, size: NSSize(width: 1370, height: 320), name: "characters.png")
    }
}
