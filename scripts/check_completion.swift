import AppKit
import RippleCore
import SwiftUI

/// Exercise real window-controller callbacks with hidden windows and isolated
/// preferences. No screen capture, visible overlays, audio, or camera access.
@main
struct CompletionCheck {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let suite = "local.ripple.completion.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ReminderSettings(startMinute: 0, endMinute: 0, displayMode: .all,
                                       soundEnabled: false, requireDrinkVerification: false)
        defaults.set(try JSONEncoder().encode(settings), forKey: "reminderSettings")
        let model = AppModel(defaults: defaults)
        let controller = ReminderWindowController(model: model, presentsWindows: false)
        defer { controller.shutdown() }
        model.onPresentReminder = { [weak controller] preview in controller?.present(preview: preview) }
        let displayCount = NSScreen.screens.count

        func expect(_ value: Bool, _ message: String) throws {
            guard value else { throw NSError(domain: "RippleCompletionCheck", code: 1,
                                            userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func waitFor(_ message: String, timeout: TimeInterval = 3, _ condition: () -> Bool) throws {
            let deadline = Date().addingTimeInterval(timeout)
            while !condition() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
            try expect(condition(), message)
        }
        func action(_ panel: ReminderPanel, _ action: ReminderAction) throws {
            let host = panel.contentView as? NSHostingView<ReminderView>
            try expect(host != nil, "Missing actual reminder view")
            host?.rootView.onAction(action)
        }
        func finishFromTwoDisplays() throws {
            try expect(controller.panels.count == displayCount, "Reminder did not target all displays")
            let first = controller.panels.first!
            let last = controller.panels.last!
            try action(first, .drank)
            try action(last, .drank)
            try waitFor("Fullscreen reminders did not close before celebration") { !model.isPresenting }
            try expect(controller.panels.isEmpty, "Fullscreen reminder remained during confetti")
            try expect(controller.celebrationPanels.count == displayCount, "Celebration lost a target display")
            var startTimes = Set<Date>()
            for panel in controller.celebrationPanels {
                try expect(!panel.isOpaque && panel.backgroundColor == .clear, "Celebration is not transparent")
                try expect(panel.ignoresMouseEvents && !panel.canBecomeKey && !panel.canBecomeMain,
                           "Celebration could capture mouse input or focus")
                try expect(!panel.isVisible, "A test window was displayed")
                if let host = panel.contentView as? NSHostingView<ConfettiCelebrationView> {
                    startTimes.insert(host.rootView.startedAt)
                }
            }
            try expect(startTimes.count == 1, "Displays do not share a celebration clock")
        }

        try expect(displayCount > 0, "This check requires a macOS graphical session")
        model.remindNow()
        try finishFromTwoDisplays()
        try expect(model.entries.count == 1, "Duplicate callbacks recorded more than one drink")
        try waitFor("Confetti windows did not expire", timeout: 4) { controller.celebrationPanels.isEmpty }

        let schedule = model.nextReminder
        model.preview()
        try finishFromTwoDisplays()
        try expect(model.entries.count == 1 && model.nextReminder == schedule, "Preview changed drink history or schedule")
        model.preview()
        try expect(controller.celebrationPanels.isEmpty && controller.panels.count == displayCount,
                   "A new reminder did not clear the old celebration")
        controller.dismiss(action: .dismiss)
        try waitFor("Dismissal did not finish") { !model.isPresenting }
        try expect(controller.celebrationPanels.isEmpty && model.entries.count == 1, "Dismissal celebrated or recorded a drink")

        model.remindNow()
        try action(controller.panels.first!, .snooze)
        try waitFor("Snooze did not finish") { !model.isPresenting }
        try expect(controller.celebrationPanels.isEmpty && model.entries.count == 1, "Snooze celebrated or recorded a drink")

        model.remindNow()
        try action(controller.panels.first!, .drank)
        controller.dismiss(action: .dismiss) // System interruption during the fade.
        try waitFor("Interrupted completion did not finish") { !model.isPresenting }
        try expect(controller.celebrationPanels.isEmpty && model.entries.count == 2,
                   "Interruption displayed confetti or discarded an already accepted drink")
        print("PASS: \(displayCount) hidden displays; reminder removal, transparent/pass-through confetti, shared clock, expiry, preview, duplicate completion, new reminder, snooze, and interruption")
    }
}
