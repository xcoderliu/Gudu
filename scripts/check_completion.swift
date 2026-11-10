import AppKit
import GuduCore
import SwiftUI

/// Exercise real window-controller callbacks with hidden windows and isolated
/// preferences. No screen capture, visible overlays, audio, or camera access.
@main
struct CompletionCheck {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let suite = "local.gudu.completion.\(UUID().uuidString)"
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
            guard value else { throw NSError(domain: "GuduCompletionCheck", code: 1,
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
        let baseline = model.entries.count
        var cameraAttempts = 0
        let fallbackController = ReminderWindowController(model: model, presentsWindows: false, startCamera: { camera in
            cameraAttempts += 1
            camera.reportUnavailable("离线模拟摄像头拒绝、缺失或采集失败。")
        })
        defer { fallbackController.shutdown() }
        model.onPresentReminder = { [weak fallbackController] preview in fallbackController?.present(preview: preview) }
        model.settings.requireDrinkVerification = true
        model.settings.autoDismissSeconds = 15 // A saved ordinary-mode choice.
        model.remindNow()
        let fallbackPanel = fallbackController.panels.first!
        let fallbackHost = fallbackPanel.contentView as! NSHostingView<ReminderView>
        try expect(fallbackHost.rootView.session.usesManualFallback && !fallbackHost.rootView.session.requiresVerification,
                   "Camera failure did not offer manual confirmation")
        try expect(fallbackHost.rootView.session.deadline == nil && model.entries.count == baseline,
                   "Camera failure auto-dismissed or recorded water")
        try expect(model.settings.requireDrinkVerification, "Temporary failure changed the saved camera preference")
        try action(fallbackPanel, .snooze)
        try waitFor("Fallback snooze did not close") { !model.isPresenting }
        try expect(model.entries.count == baseline, "Fallback snooze recorded water")

        model.remindNow()
        let retryPanel = fallbackController.panels.first!
        let retrySession = (retryPanel.contentView as! NSHostingView<ReminderView>).rootView.session
        retrySession.camera.onAttemptStart?() // Retry transition without camera access.
        try expect(retrySession.requiresVerification && !retrySession.usesManualFallback, "Retry did not restore verification")
        try action(retryPanel, .drank)
        try expect(model.isPresenting && model.entries.count == baseline, "Unverified retry could record water")
        retrySession.camera.reportUnavailable("离线模拟重试失败。")
        try action(retryPanel, .drank)
        try action(retryPanel, .drank)
        try waitFor("Manual fallback confirmation did not finish") { !model.isPresenting }
        try expect(model.entries.count == baseline + 1 && cameraAttempts == 2,
                   "Fallback completion did not record exactly one drink or next session skipped camera retry")

        let verificationTest = ReminderSession(preview: true, servingML: 250, seconds: 15, requiresVerification: true)
        verificationTest.camera.reportUnavailable("离线模拟识别测试错误。")
        try expect(!verificationTest.usesManualFallback && verificationTest.requiresVerification,
                   "A recognition test exposed a fake successful manual completion")
        print("PASS: \(displayCount) hidden displays; completion/confetti, camera-failure manual confirmation, snooze, retry gating, no automatic recording, and preview isolation; no camera access")
    }
}
