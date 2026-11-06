import Foundation

/// Daily wall-clock schedule. The start is inclusive and the end is exclusive.
/// An equal start and end means all day; an earlier end means an overnight window.
public struct ReminderSchedule: Equatable, Sendable {
    public let startMinute: Int
    public let endMinute: Int
    public let intervalMinutes: Int

    public init(startMinute: Int, endMinute: Int, intervalMinutes: Int) {
        self.startMinute = min(max(startMinute, 0), 1439)
        self.endMinute = min(max(endMinute, 0), 1439)
        self.intervalMinutes = min(max(intervalMinutes, 1), 240)
    }

    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        if startMinute == endMinute { return true }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinute < endMinute {
            return minute >= startMinute && minute < endMinute
        }
        return minute >= startMinute || minute < endMinute
    }

    /// When outside the daily window, the next reminder is at the next start.
    /// Reminders that would cross the daily end move to the next window's start.
    public func nextReminder(
        after date: Date,
        delay: TimeInterval? = nil,
        calendar: Calendar = .current
    ) -> Date {
        guard isActive(at: date, calendar: calendar) else {
            return nextStart(after: date, calendar: calendar)
        }
        let candidate = date.addingTimeInterval(max(1, delay ?? Double(intervalMinutes * 60)))
        if startMinute == endMinute { return candidate }

        // Test against this window's end, rather than just checking whether the
        // candidate is active: a long delay must not jump into another window.
        let end = nextWallTime(minute: endMinute, after: date, calendar: calendar)
        if candidate < end { return candidate }
        return nextStart(after: end.addingTimeInterval(-1), calendar: calendar)
    }

    public func nextStart(after date: Date, calendar: Calendar = .current) -> Date {
        nextWallTime(minute: startMinute, after: date, calendar: calendar)
    }

    private func nextWallTime(minute: Int, after date: Date, calendar: Calendar) -> Date {
        var parts = DateComponents()
        parts.hour = minute / 60
        parts.minute = minute % 60
        parts.second = 0
        // Calendar handles daylight-saving gaps and repeated hours. Do not add
        // 86,400 seconds to represent a local day.
        return calendar.nextDate(
            after: date,
            matching: parts,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? date.addingTimeInterval(24 * 60 * 60)
    }
}
