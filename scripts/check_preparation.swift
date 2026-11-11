import AppKit
import Foundation
import GuduCore
import SwiftUI

/// Injected time and isolated preferences; no camera, actual sleep, or visible windows.
@main
struct PreparationCheck {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        func at(_ time: String) -> Date { formatter.date(from: "2026-11-09 \(time)")! }
        let suite = "local.gudu.preparation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var instant = at("09:15:00")
        let model = AppModel(defaults: defaults, clock: { instant }, startsTimer: false)
        let bubble = PreparationBubbleController(presentsWindows: false)
        var messages: [Int] = []
        var fullScreens = 0
        var checks = 0
        func expect(_ condition: Bool, _ message: String) throws {
            guard condition else { throw NSError(domain: "GuduPreparation", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
            checks += 1
        }
        model.onPresentPreparation = { minutes in messages.append(minutes); bubble.present(minutes: minutes, mode: model.settings.displayMode) }
        model.onDismissPreparation = { bubble.dismiss() }
        model.onPresentReminder = { _ in fullScreens += 1 }
        defer { model.onPresentPreparation = nil; model.onDismissPreparation = nil; model.onPresentReminder = nil; bubble.dismiss() }
        func advance(_ time: String) {
            let target = at(time)
            while instant < target {
                instant = min(instant.addingTimeInterval(30), target)
                model.tick()
            }
        }
        func reset(_ time: String = "09:15:00") {
            if model.isPresenting { model.finishReminder(.dismiss, preview: false) }
            instant = at(time)
            model.settings = ReminderSettings()
            model.reschedule()
            model.tick()
            messages.removeAll()
            fullScreens = 0
        }
        let original = model.nextReminder
        advance("09:54:59")
        try expect(messages.isEmpty, "Refill bubble fired early")
        advance("09:55:00")
        try expect(messages == [5], "Five-minute bubble did not fire")
        // Hosting-view minimums are applied on a later layout pass. Check the
        // actual NSPanel after that pass, not just the initially requested size.
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        try expect(bubble.panels.allSatisfy { $0.frame.size == NSSize(width: 340, height: 100) }, "Hosting layout enlarged the bubble window")
        try expect(bubble.panels.allSatisfy { $0.contentView?.frame.size == NSSize(width: 340, height: 100) }, "Bubble content does not match the compact window")
        try expect(!bubble.panels.isEmpty && bubble.panels.allSatisfy { !$0.isVisible && !$0.canBecomeKey && !$0.canBecomeMain }, "Bubble stole focus or displayed a QA window")
        try expect(bubble.panels.allSatisfy { panel in NSScreen.screens.contains { $0.visibleFrame.contains(panel.frame) } }, "Bubble falls outside the working display")
        try expect(model.nextReminder == original && model.entries.isEmpty && !model.isPresenting, "Refill changed the full reminder or water history")
        model.tick(); advance("09:55:30")
        try expect(messages == [5], "Duplicate timer delivered duplicate refill")
        model.settings.preparationLeadMinutes = 3
        try expect(bubble.panels.isEmpty && model.nextReminder == original, "Lead change failed to clear bubble or reset drink time")
        advance("09:57:00")
        try expect(messages == [5], "Changing lead delivered a second bubble for the same drink")
        advance("10:00:00")
        try expect(fullScreens == 1 && model.isPresenting && bubble.panels.isEmpty, "Full reminder was lost or overlapped the bubble")
        model.finishReminder(.drank, preview: false)
        try expect(model.entries.count == 1, "Normal completion failed")
        advance("10:42:00")
        try expect(messages == [5, 3], "Next cycle lost its new lead setting")
        model.recordDrink()
        try expect(bubble.panels.isEmpty, "Recording water left a stale refill bubble")

        reset()
        model.settings.preparationLeadMinutes = 0
        try expect(model.nextReminder == original, "Disabling refill changed drink time")
        advance("09:59:00")
        try expect(messages.isEmpty, "Disabled refill still fired")
        reset()
        model.previewPreparation()
        try expect(messages == [5] && model.nextReminder == original && !model.isPresenting, "Preview changed scheduler state")
        advance("09:55:00")
        try expect(messages == [5, 5], "Preview consumed the real preparation reminder")
        model.toggleEnabled()
        try expect(bubble.panels.isEmpty && model.nextReminder == nil, "Pause retained preparation")

        reset()
        advance("09:50:00")
        model.settings.preparationLeadMinutes = 10
        advance("09:55:00")
        try expect(messages.isEmpty && model.nextReminder == original, "Missed lead was immediately backfilled")
        reset()
        advance("09:50:00")
        model.preview()
        advance("09:56:00")
        model.finishReminder(.dismiss, preview: true)
        advance("09:57:00")
        try expect(messages.isEmpty, "Preview caused a stale preparation afterwards")

        reset()
        model.settings.preparationLeadMinutes = 3
        model.remindNow(); model.finishReminder(.snooze, preview: false)
        advance("09:20:00")
        try expect(messages.isEmpty && fullScreens == 2, "Snooze sent another refill or lost the drink reminder")
        model.finishReminder(.dismiss, preview: false)

        reset()
        advance("09:50:00")
        let center = NSWorkspace.shared.notificationCenter
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        instant = at("09:56:00")
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        advance("09:57:00")
        try expect(messages.isEmpty && model.nextReminder == original, "Wake backfilled a missed preparation")
        reset()
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        instant = at("10:20:00")
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        advance("10:20:30")
        try expect(messages.isEmpty && fullScreens == 1, "Catch-up reminder added another refill")

        reset("08:30:00")
        advance("09:00:00")
        try expect(messages.isEmpty && fullScreens == 1, "Preparation ignored quiet hours")
        reset()
        model.settings.weekdays = []
        advance("09:55:00")
        try expect(messages.isEmpty && fullScreens == 0, "Preparation ignored selected weekdays")
        model.settings.preparationLeadMinutes = 10
        let restored = AppModel(defaults: defaults, clock: { instant }, startsTimer: false)
        try expect(restored.settings.preparationLeadMinutes == 10, "Preparation preference was not persisted")

        bubble.present(minutes: 5, mode: .all)
        try expect(bubble.panels.count == NSScreen.screens.count, "All-screen bubbles did not follow display mode")
        bubble.dismiss()
        try expect(bubble.panels.isEmpty, "Close failed to clean bubble windows")
        if let path = CommandLine.arguments.dropFirst().first {
            // Export the controller's real, settled NSPanel content. A separately
            // constrained ImageRenderer can hide native-window sizing regressions.
            bubble.present(minutes: 3, mode: .cursor)
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            guard let panel = bubble.panels.first, let content = panel.contentView else { fatalError("Missing bubble window") }
            content.layoutSubtreeIfNeeded()
            let bounds = content.bounds
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 2),
                pixelsHigh: Int(bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.size = bounds.size
            content.cacheDisplay(in: bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
            print("Rendered actual NSPanel content: \(panel.frame.size), \(path)")
        }
        bubble.present(minutes: 5, mode: .cursor)
        let timeout = Date().addingTimeInterval(17)
        while !bubble.panels.isEmpty && Date() < timeout {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        try expect(bubble.panels.isEmpty, "Bubble failed to dismiss itself after 15 seconds")
        print("PASS: \(checks) refill integration assertions, hidden windows only")
    }
}
