import AppKit
import Foundation
import GuduCore

/// Real timer integration check with isolated preferences and no reminder windows.
@main
struct AppModelSmokeTest {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let suite = "local.gudu.smoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ReminderSettings(intervalMinutes: 1, startMinute: 0, endMinute: 0)
        defaults.set(try JSONEncoder().encode(settings), forKey: "reminderSettings")
        let model = AppModel(defaults: defaults)
        var disabledVerification = false
        model.onVerificationDisabled = { disabledVerification = true }
        var fired = false
        model.onPresentReminder = { preview in
            if preview { model.finishReminder(.dismiss, preview: true) }
            else {
                fired = true
                model.finishReminder(.snooze, preview: false)
            }
        }

        func expect(_ value: Bool, _ message: String) throws {
            guard value else {
                throw NSError(domain: "GuduSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }

        model.settings.requireDrinkVerification = true
        model.settings.requireDrinkVerification = false
        try expect(disabledVerification, "Disabling verification did not request camera cleanup")

        model.settings.weekdays = []
        try expect(model.nextReminder == nil && model.countdown == "未选提醒日", "Empty weekdays left an automatic reminder")
        model.preview()
        try expect(!model.isPresenting && model.entries.isEmpty, "Empty weekdays blocked a preview or recorded water")
        model.recordDrink()
        try expect(model.todayML == 250 && model.nextReminder == nil, "Manual recording changed the empty weekday plan")
        model.undoLastDrink()

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let nextDay = ReminderWeekday(rawValue: calendar.component(.weekday, from: tomorrow))!
        model.settings.weekdays = [nextDay]
        try expect(model.nextReminder == calendar.startOfDay(for: tomorrow), "Weekday change did not immediately plan the next selected midnight")
        let saved = try JSONDecoder().decode(ReminderSettings.self, from: defaults.data(forKey: "reminderSettings")!)
        try expect(saved.weekdays == [nextDay], "Weekdays were not persisted")
        model.settings.weekdays = ReminderWeekday.everyDay

        let before = model.nextReminder
        model.preview()
        try expect(model.nextReminder == before && model.entries.isEmpty && !model.isPresenting,
                   "Preview changed the schedule, recorded water, or stayed presented")
        model.recordDrink()
        try expect(model.todayML == 250, "Drink was not recorded")
        model.undoLastDrink()
        try expect(model.todayML == 0, "Undo did not remove the test drink")

        print("Waiting for the real one-minute AppModel timer…")
        fflush(stdout)
        let timeout = Date().addingTimeInterval(68)
        while !fired && Date() < timeout {
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
        try expect(fired, "Automatic reminder did not fire within 68 seconds")
        try expect(!model.isPresenting && model.entries.isEmpty, "Snooze recorded water or stayed presented")
        let remaining = model.nextReminder?.timeIntervalSinceNow ?? 0
        try expect(remaining > 298 && remaining <= 301, "Snooze did not schedule five minutes")
        model.toggleEnabled()
        try expect(!model.settings.isEnabled && model.nextReminder == nil, "Pause left a pending reminder")
        print("PASS: weekday pause/persistence/reschedule, manual actions without selected dates, verification opt-out cleanup, preview, record/undo, real timer, snooze, and pause")
    }
}
