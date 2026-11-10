import Foundation

/// A single catch-up after returning, with the original regular cadence kept
/// separately so a nearby normal reminder can replace it.
public struct ReminderRecoveryPlan: Equatable, Sendable {
    public let regularReminder: Date?
    public let catchUpReminder: Date?

    public init(due: Date?, interrupted: Bool = false, at date: Date,
                schedule: ReminderSchedule, calendar: Calendar = .current) {
        guard let due else {
            regularReminder = schedule.nextReminder(after: date, calendar: calendar)
            catchUpReminder = nil
            return
        }
        guard schedule.isActive(at: date, calendar: calendar) else {
            regularReminder = schedule.nextReminder(after: date, calendar: calendar)
            catchUpReminder = nil
            return
        }
        regularReminder = schedule.nextRegularReminder(after: date, preserving: due, calendar: calendar)
        let buffered = date.addingTimeInterval(30)
        let nextIsClose = regularReminder.map { $0.timeIntervalSince(date) <= 5 * 60 } ?? false
        catchUpReminder = (due <= date || interrupted) && !nextIsClose && schedule.isActive(at: buffered, calendar: calendar)
            ? buffered : nil
    }
}
