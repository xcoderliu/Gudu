import Foundation
import XCTest
@testable import RippleCore

final class ReminderScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }

    private func date(_ text: String, in calendar: Calendar? = nil) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar ?? self.calendar
        formatter.timeZone = (calendar ?? self.calendar).timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)!
    }

    private let daytime = ReminderSchedule(startMinute: 540, endMinute: 1260, intervalMinutes: 45)

    func testStartInclusiveAndEndExclusive() {
        XCTAssertFalse(daytime.isActive(at: date("2026-11-06 08:59:59"), calendar: calendar))
        XCTAssertTrue(daytime.isActive(at: date("2026-11-06 09:00:00"), calendar: calendar))
        XCTAssertTrue(daytime.isActive(at: date("2026-11-06 20:59:59"), calendar: calendar))
        XCTAssertFalse(daytime.isActive(at: date("2026-11-06 21:00:00"), calendar: calendar))
    }

    func testBeforeStartRemindsAtStart() {
        XCTAssertEqual(daytime.nextReminder(after: date("2026-11-06 08:00:00"), calendar: calendar),
                       date("2026-11-06 09:00:00"))
    }

    func testActiveIntervalAndDayBoundary() {
        XCTAssertEqual(daytime.nextReminder(after: date("2026-11-06 10:10:00"), calendar: calendar),
                       date("2026-11-06 10:55:00"))
        XCTAssertEqual(daytime.nextReminder(after: date("2026-11-06 20:30:00"), calendar: calendar),
                       date("2026-11-07 09:00:00"))
        XCTAssertEqual(daytime.nextReminder(after: date("2026-11-06 20:15:00"), calendar: calendar),
                       date("2026-11-07 09:00:00"))
        XCTAssertEqual(daytime.nextReminder(after: date("2026-11-06 22:00:00"), calendar: calendar),
                       date("2026-11-07 09:00:00"))
    }

    func testOvernightWindow() {
        let schedule = ReminderSchedule(startMinute: 22 * 60, endMinute: 2 * 60, intervalMinutes: 45)
        XCTAssertTrue(schedule.isActive(at: date("2026-11-06 23:00:00"), calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: date("2026-11-07 01:00:00"), calendar: calendar))
        XCTAssertFalse(schedule.isActive(at: date("2026-11-07 02:00:00"), calendar: calendar))
        XCTAssertEqual(schedule.nextReminder(after: date("2026-11-06 23:45:00"), calendar: calendar),
                       date("2026-11-07 00:30:00"))
        XCTAssertEqual(schedule.nextReminder(after: date("2026-11-07 01:30:00"), calendar: calendar),
                       date("2026-11-07 22:00:00"))
    }

    func testEqualTimesMeanAllDay() {
        let schedule = ReminderSchedule(startMinute: 540, endMinute: 540, intervalMinutes: 45)
        let now = date("2026-11-06 23:45:00")
        XCTAssertTrue(schedule.isActive(at: now, calendar: calendar))
        XCTAssertEqual(schedule.nextReminder(after: now, calendar: calendar), date("2026-11-07 00:30:00"))
    }

    func testSnoozeRespectsQuietHours() {
        XCTAssertEqual(daytime.nextReminder(after: date("2026-11-06 20:58:00"), delay: 300, calendar: calendar),
                       date("2026-11-07 09:00:00"))
        XCTAssertEqual(daytime.nextReminder(after: date("2026-11-06 10:00:00"), delay: 300, calendar: calendar),
                       date("2026-11-06 10:05:00"))
    }

    func testLongIntervalDoesNotSkipNextShortWindow() {
        let schedule = ReminderSchedule(startMinute: 540, endMinute: 550, intervalMinutes: 240)
        XCTAssertEqual(schedule.nextReminder(after: date("2026-11-06 09:05:00"), calendar: calendar),
                       date("2026-11-07 09:00:00"))
    }

    func testDaylightSavingSpringGap() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let schedule = ReminderSchedule(startMinute: 150, endMinute: 720, intervalMinutes: 45)
        let before = date("2026-03-08 00:00:00", in: calendar)
        XCTAssertEqual(schedule.nextReminder(after: before, calendar: calendar),
                       date("2026-03-08 03:00:00", in: calendar))
    }

    func testSettingsNormalizeCorruptValues() {
        let settings = ReminderSettings(intervalMinutes: -4, startMinute: 4000, endMinute: -1,
                                        autoDismissSeconds: 999, servingML: 0, dailyGoalML: 9999)
        XCTAssertEqual(settings.intervalMinutes, 1)
        XCTAssertEqual(settings.startMinute, 1439)
        XCTAssertEqual(settings.endMinute, 0)
        XCTAssertEqual(settings.autoDismissSeconds, 30)
        XCTAssertEqual(settings.servingML, 50)
        XCTAssertEqual(settings.dailyGoalML, 5000)
    }
}
