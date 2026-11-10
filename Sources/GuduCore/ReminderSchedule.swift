import Foundation

/// Calendar weekday values, ordered Monday first for the settings UI.
public enum ReminderWeekday: Int, CaseIterable, Codable, Sendable, Identifiable {
    case monday = 2, tuesday = 3, wednesday = 4, thursday = 5, friday = 6, saturday = 7, sunday = 1
    public var id: Int { rawValue }
    public static let everyDay = Set(allCases)
    public static let workdays: Set<Self> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public static let weekend: Set<Self> = [.saturday, .sunday]
}

/// Weekly wall-clock schedule. Overnight windows belong to their start day.
/// Equal start/end means the selected calendar dates are active all day.
public struct ReminderSchedule: Equatable, Sendable {
    public let startMinute: Int
    public let endMinute: Int
    public let intervalMinutes: Int
    public let weekdays: Set<ReminderWeekday>

    public init(startMinute: Int, endMinute: Int, intervalMinutes: Int,
                weekdays: Set<ReminderWeekday> = ReminderWeekday.everyDay) {
        self.startMinute = min(max(startMinute, 0), 1439)
        self.endMinute = min(max(endMinute, 0), 1439)
        self.intervalMinutes = min(max(intervalMinutes, 1), 240)
        self.weekdays = weekdays
    }

    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        activeWindow(at: date, calendar: calendar) != nil
    }

    /// No selected dates means no automatic reminder. A delay never skips a
    /// quiet gap merely because it lands inside a later active window.
    public func nextReminder(
        after date: Date,
        delay: TimeInterval? = nil,
        calendar: Calendar = .current
    ) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        guard let window = activeWindow(at: date, calendar: calendar) else {
            return nextStart(after: date, calendar: calendar)
        }
        let requestedDelay = delay.flatMap { $0.isFinite ? $0 : nil } ?? Double(intervalMinutes * 60)
        let candidate = date.addingTimeInterval(max(1, requestedDelay))
        if startMinute == endMinute && weekdays == ReminderWeekday.everyDay { return candidate }
        let end = startMinute == endMinute
            ? endOfConsecutiveDays(containing: date, calendar: calendar) ?? window.end : window.end
        if candidate < end { return candidate }
        return nextStart(after: end.addingTimeInterval(-1), calendar: calendar)
    }

    public func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        let today = calendar.startOfDay(for: date)
        // Two weeks also cover an entire local date skipped by a zone change.
        for offset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let window = window(starting: day, calendar: calendar), window.start > date else { continue }
            return window.start
        }
        return nil
    }

    /// Keep the original cadence after missed reminders, restarting at the
    /// current window's start if a quiet gap separated the two dates.
    public func nextRegularReminder(after date: Date, preserving due: Date,
                                    calendar: Calendar = .current) -> Date? {
        guard let window = activeWindow(at: date, calendar: calendar) else {
            return nextStart(after: date, calendar: calendar)
        }
        if due > date { return due }
        var anchor = max(due, window.start)
        if startMinute == endMinute {
            // Consecutive selected whole days are one uninterrupted window.
            if weekdays == ReminderWeekday.everyDay { anchor = due }
            else {
                var start = window.start
                for _ in 0..<6 {
                    guard let previous = calendar.date(byAdding: .day, value: -1, to: start),
                          let day = ReminderWeekday(rawValue: calendar.component(.weekday, from: previous)),
                          weekdays.contains(day) else { break }
                    start = previous
                }
                anchor = max(due, start)
            }
        }
        let interval = Double(intervalMinutes * 60)
        let steps = floor(date.timeIntervalSince(anchor) / interval) + 1
        let candidate = anchor.addingTimeInterval(steps * interval)
        // nextReminder also applies quiet gaps and consecutive all-day dates.
        return nextReminder(after: date, delay: candidate.timeIntervalSince(date), calendar: calendar)
    }

    private func activeWindow(at date: Date, calendar: Calendar) -> DateInterval? {
        let today = calendar.startOfDay(for: date)
        if let window = window(starting: today, calendar: calendar), date >= window.start && date < window.end {
            return window
        }
        if startMinute > endMinute,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let window = window(starting: yesterday, calendar: calendar), date >= window.start && date < window.end {
            return window
        }
        return nil
    }

    private func window(starting day: Date, calendar: Calendar) -> DateInterval? {
        guard let weekday = ReminderWeekday(rawValue: calendar.component(.weekday, from: day)), weekdays.contains(weekday),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else { return nil }
        if startMinute == endMinute {
            return DateInterval(start: calendar.startOfDay(for: day), end: calendar.startOfDay(for: tomorrow))
        }
        guard let start = wallTime(minute: startMinute, on: day, calendar: calendar),
              let end = wallTime(minute: endMinute, on: startMinute > endMinute ? tomorrow : day, calendar: calendar),
              end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private func endOfConsecutiveDays(containing date: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let weekday = ReminderWeekday(rawValue: calendar.component(.weekday, from: day)) else { continue }
            if !weekdays.contains(weekday) { return calendar.startOfDay(for: day) }
        }
        return nil
    }

    private func wallTime(minute: Int, on day: Date, calendar: Calendar) -> Date? {
        var parts = DateComponents()
        parts.hour = minute / 60
        parts.minute = minute % 60
        parts.second = 0
        // Calendar handles daylight-saving gaps and repeated hours. Do not add
        // 86,400 seconds to represent a local day.
        guard let date = calendar.nextDate(
            after: calendar.startOfDay(for: day).addingTimeInterval(-1),
            matching: parts,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ), calendar.isDate(date, inSameDayAs: day) else { return nil }
        return date
    }
}
