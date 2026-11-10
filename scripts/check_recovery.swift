import AppKit
import Foundation
import GuduCore

/// Exercise AppModel with an injected clock and in-process workspace events.
/// No waiting, visible windows, real sleep/lock, camera, or user preferences.
@main
struct RecoveryCheck {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        let base = formatter.date(from: "2026-11-09 09:15:00")!
        var checks = 0
        func expect(_ condition: Bool, _ message: String) throws {
            guard condition else { throw NSError(domain: "GuduRecovery", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
            checks += 1
        }
        let center = NSWorkspace.shared.notificationCenter
        func event(_ name: Notification.Name) { center.post(name: name, object: nil) }

        // Each case owns separate disposable preferences; the clock starts
        // with a normal deadline at 10:00 (45 minutes after 09:15).
        func scenario(_ body: (AppModel, (String) -> Void, () -> Int) throws -> Void) throws {
            let suite = "local.gudu.recovery.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let settings = ReminderSettings(intervalMinutes: 45, startMinute: 540, endMinute: 1260)
            defaults.set(try JSONEncoder().encode(settings), forKey: "reminderSettings")
            var instant = base
            let model = AppModel(defaults: defaults, clock: { instant }, startsTimer: false)
            var presentations = 0
            model.onPresentReminder = { _ in presentations += 1 }
            model.onDismissReminder = {
                if model.isPresenting { model.finishReminder(.dismiss, preview: false) }
            }
            defer { model.onPresentReminder = nil; model.onDismissReminder = nil }
            try body(model, { instant = formatter.date(from: "2026-11-09 \($0)")! }, { presentations })
        }
        func at(_ time: String) -> Date { formatter.date(from: "2026-11-09 \(time)")! }
        try scenario { model, time, count in
            event(NSWorkspace.willSleepNotification)
            try expect(model.nextReminder == nil, "Sleep must hide the active countdown")
            time("09:50:00"); event(NSWorkspace.didWakeNotification)
            try expect(model.nextReminder == at("10:00:00"), "Early wake reset the original deadline")
            time("10:00:00"); model.tick(); time("10:00:30"); model.tick()
            try expect(count() == 1, "A timer gap must buffer then present exactly once")
        }
        try scenario { model, time, count in
            event(NSWorkspace.willSleepNotification); event(NSWorkspace.sessionDidResignActiveNotification)
            time("10:20:00"); event(NSWorkspace.didWakeNotification)
            try expect(model.nextReminder == nil, "Wake alone must not bypass the inactive session")
            event(NSWorkspace.sessionDidBecomeActiveNotification)
            try expect(model.nextReminder == at("10:20:30"), "Missed reminder did not get a 30-second buffer")
            event(NSWorkspace.sessionDidBecomeActiveNotification)
            try expect(model.nextReminder == at("10:20:30"), "Duplicate recovery event reset the buffer")
            time("10:20:29"); model.tick(); try expect(count() == 0, "Catch-up fired early")
            time("10:20:30"); model.tick(); model.tick()
            try expect(count() == 1, "Catch-up must fire only once")
            model.finishReminder(.drank, preview: false)
            try expect(model.entries.count == 1 && model.nextReminder == at("11:05:30"), "Accepted drink did not restart the interval")
        }
        try scenario { model, time, count in
            event(NSWorkspace.willSleepNotification); time("10:40:00"); event(NSWorkspace.didWakeNotification)
            try expect(model.nextReminder == at("10:45:00"), "Five-minute rule must preserve the normal reminder")
            for minute in 41...45 { time("10:\(minute):00"); model.tick() }
            try expect(count() == 1, "Skipped catch-up lost or duplicated the normal reminder")
        }
        try scenario { model, time, count in
            event(NSWorkspace.willSleepNotification); time("10:20:00"); event(NSWorkspace.didWakeNotification)
            model.recordDrink()
            try expect(model.nextReminder == at("11:05:00"), "Manual drink failed to cancel catch-up")
            time("10:20:30"); model.tick(); try expect(count() == 0, "Cancelled catch-up still fired")
        }
        try scenario { model, time, _ in
            event(NSWorkspace.willSleepNotification); time("10:20:00"); event(NSWorkspace.didWakeNotification)
            model.toggleEnabled()
            try expect(model.nextReminder == nil, "Pause did not clear catch-up")
            model.toggleEnabled()
            try expect(model.nextReminder == at("11:05:00"), "Resume revived stale catch-up")
        }
        try scenario { model, time, _ in
            event(NSWorkspace.willSleepNotification); time("10:20:00"); event(NSWorkspace.didWakeNotification)
            time("10:20:10"); event(NSWorkspace.willSleepNotification)
            time("10:30:00"); event(NSWorkspace.didWakeNotification)
            try expect(model.nextReminder == at("10:30:30"), "Second sleep lost pending catch-up")
        }
        try scenario { model, time, _ in
            model.remindNow()
            // Complete the dismissal after waking to reproduce the real fade.
            model.onDismissReminder = {}
            event(NSWorkspace.willSleepNotification); time("09:20:00"); event(NSWorkspace.didWakeNotification)
            model.finishReminder(.dismiss, preview: false)
            try expect(model.nextReminder == at("09:20:30") && !model.isPresenting, "Asynchronous system dismissal erased an interrupted reminder")
        }
        try scenario { model, time, _ in
            model.preview(); event(NSWorkspace.willSleepNotification)
            time("09:20:00"); event(NSWorkspace.didWakeNotification)
            try expect(model.nextReminder == at("10:00:00"), "An interrupted preview created catch-up")
        }
        try scenario { model, time, _ in
            model.remindNow(); model.finishReminder(.snooze, preview: false)
            event(NSWorkspace.willSleepNotification); time("09:18:00"); event(NSWorkspace.didWakeNotification)
            try expect(model.nextReminder == at("09:20:00"), "Early wake reset a snoozed deadline")
        }
        try scenario { model, time, _ in
            event(NSWorkspace.willSleepNotification); time("22:00:00"); event(NSWorkspace.didWakeNotification)
            let next = formatter.date(from: "2026-11-10 09:00:00")!
            try expect(model.nextReminder == next, "Quiet hours allowed catch-up")
        }
        print("PASS: \(checks) AppModel recovery assertions; isolated clock/events, no camera or windows")
    }
}
