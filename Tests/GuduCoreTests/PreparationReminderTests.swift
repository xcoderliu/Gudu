import Foundation
import XCTest
@testable import GuduCore

final class PreparationReminderTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return result
    }
    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: text)!
    }
    private let start = "2026-11-09 09:15:00"
    private let due = "2026-11-09 10:00:00"

    func testLeadChoicesAndExactBoundary() throws {
        for minutes in [3, 5, 10] {
            let settings = ReminderSettings(preparationLeadMinutes: minutes)
            let plan = try XCTUnwrap(PreparationReminderPlan(drinkDate: date(due), settings: settings,
                                                            plannedAt: date(start), calendar: calendar))
            XCTAssertEqual(plan.date, date(due).addingTimeInterval(-Double(minutes * 60)))
            XCTAssertFalse(plan.shouldPresent(after: plan.date.addingTimeInterval(-2), at: plan.date.addingTimeInterval(-1)))
            XCTAssertTrue(plan.shouldPresent(after: plan.date.addingTimeInterval(-1), at: plan.date))
            XCTAssertTrue(plan.shouldPresent(after: plan.date.addingTimeInterval(-1), at: plan.date.addingTimeInterval(59)))
            XCTAssertFalse(plan.shouldPresent(after: plan.date, at: plan.date))
            XCTAssertFalse(plan.shouldPresent(after: plan.date.addingTimeInterval(-1), at: plan.date.addingTimeInterval(60)))
            XCTAssertFalse(plan.shouldPresent(after: plan.date, at: date(due)))
        }
    }

    func testDisabledMissingAndShortSchedules() {
        for settings in [ReminderSettings(isEnabled: false), ReminderSettings(preparationLeadMinutes: 0),
                         ReminderSettings(intervalMinutes: 5), ReminderSettings(intervalMinutes: 3)] {
            XCTAssertNil(PreparationReminderPlan(drinkDate: date(due), settings: settings, plannedAt: date(start), calendar: calendar))
        }
        XCTAssertNil(PreparationReminderPlan(drinkDate: nil, settings: ReminderSettings(), plannedAt: date(start), calendar: calendar))
    }

    func testNeverPlansAnAlreadyMissedBubble() {
        for now in ["2026-11-09 09:55:00", "2026-11-09 09:57:00", due] {
            XCTAssertNil(PreparationReminderPlan(drinkDate: date(due), settings: ReminderSettings(), plannedAt: date(now), calendar: calendar))
        }
    }

    func testQuietHoursAndUnselectedDates() {
        let settings = ReminderSettings()
        for deadline in ["2026-11-09 09:00:00", "2026-11-09 09:03:00", "2026-11-14 10:00:00", "2026-11-09 18:30:00"] {
            XCTAssertNil(PreparationReminderPlan(drinkDate: date(deadline), settings: settings,
                                                 plannedAt: date("2026-11-09 08:00:00"), calendar: calendar))
        }
    }

    func testOvernightAndConsecutiveAllDayDates() throws {
        let overnight = ReminderSettings(startMinute: 22 * 60, endMinute: 120, weekdays: [.friday])
        let plan = try XCTUnwrap(PreparationReminderPlan(drinkDate: date("2026-11-14 00:02:00"), settings: overnight,
                                                        plannedAt: date("2026-11-13 23:00:00"), calendar: calendar))
        XCTAssertEqual(plan.date, date("2026-11-13 23:57:00"))
        let allDay = ReminderSettings(startMinute: 0, endMinute: 0, weekdays: [.monday, .tuesday])
        XCTAssertNotNil(PreparationReminderPlan(drinkDate: date("2026-11-10 00:02:00"), settings: allDay,
                                                plannedAt: date("2026-11-09 23:00:00"), calendar: calendar))
    }

    func testDoesNotBridgeAShortQuietGap() {
        let settings = ReminderSettings(startMinute: 60, endMinute: 59, weekdays: ReminderWeekday.everyDay)
        XCTAssertNil(PreparationReminderPlan(drinkDate: date("2026-11-10 01:02:00"), settings: settings,
                                             plannedAt: date("2026-11-10 00:30:00"), calendar: calendar))
    }

    func testRefillSettingsMigrateAndRoundTripWithoutResettingSchedule() throws {
        let old = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"intervalMinutes":30,"soundEnabled":true}"#.utf8))
        XCTAssertEqual(old.preparationLeadMinutes, 5)
        XCTAssertTrue(old.soundEnabled)
        XCTAssertEqual(old.intervalMinutes, 30)
        for minutes in [0, 3, 5, 10] {
            var changed = old
            changed.preparationLeadMinutes = minutes
            XCTAssertTrue(changed.hasSameSchedule(as: old))
            XCTAssertEqual(try JSONDecoder().decode(ReminderSettings.self, from: JSONEncoder().encode(changed)), changed)
        }
        XCTAssertEqual(ReminderSettings(preparationLeadMinutes: -1).preparationLeadMinutes, 5)
        XCTAssertEqual(ReminderSettings(preparationLeadMinutes: 60).preparationLeadMinutes, 5)
    }
}
