import Foundation

/// A refill bubble belongs to one normal drink deadline. It never creates a
/// new drink deadline, crosses quiet hours, or catches up after being missed.
public struct PreparationReminderPlan: Equatable, Sendable {
    public let drinkDate: Date
    public let date: Date

    public init?(drinkDate: Date?, settings: ReminderSettings, plannedAt: Date,
                 calendar: Calendar = .current) {
        guard settings.isEnabled, let drinkDate,
              [3, 5, 10].contains(settings.preparationLeadMinutes),
              settings.intervalMinutes > settings.preparationLeadMinutes else { return nil }
        let candidate = drinkDate.addingTimeInterval(-Double(settings.preparationLeadMinutes * 60))
        guard candidate > plannedAt,
              settings.schedule.isActive(at: candidate, calendar: calendar),
              settings.schedule.isActive(at: drinkDate, calendar: calendar),
              settings.schedule.nextReminder(after: candidate, delay: drinkDate.timeIntervalSince(candidate),
                                             calendar: calendar) == drinkDate else { return nil }
        self.drinkDate = drinkDate
        date = candidate
    }

    /// Tolerate a small timer delay, but do not deliver old bubbles on wake.
    public func shouldPresent(after previousTick: Date, at now: Date) -> Bool {
        previousTick < date && now >= date && now.timeIntervalSince(date) < 60 && now < drinkDate
    }
}
