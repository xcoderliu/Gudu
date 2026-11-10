import XCTest
@testable import GuduCore

final class ReminderRecoveryPlanTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }
    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)!
    }
    private let schedule = ReminderSchedule(startMinute: 540, endMinute: 1260, intervalMinutes: 45)
    private func plan(_ recovery: String, due: String = "2026-11-09 10:00:00", interrupted: Bool = false,
                      schedule: ReminderSchedule? = nil) -> ReminderRecoveryPlan {
        ReminderRecoveryPlan(due: date(due), interrupted: interrupted, at: date(recovery),
                             schedule: schedule ?? self.schedule, calendar: calendar)
    }
    func testReturningBeforeDuePreservesOriginalDeadline() {
        let value = plan("2026-11-09 09:50:00")
        XCTAssertEqual(value.regularReminder, date("2026-11-09 10:00:00"))
        XCTAssertNil(value.catchUpReminder)
    }
    func testMissedReminderGetsThirtySecondBuffer() {
        let value = plan("2026-11-09 10:20:00")
        XCTAssertEqual(value.regularReminder, date("2026-11-09 10:45:00"))
        XCTAssertEqual(value.catchUpReminder, date("2026-11-09 10:20:30"))
    }
    func testExactlyDueCountsAsMissedOnReturn() {
        XCTAssertEqual(plan("2026-11-09 10:00:00").catchUpReminder, date("2026-11-09 10:00:30"))
    }
    func testMultipleMissesAreCombinedAndCadenceIsKept() {
        let value = plan("2026-11-09 13:10:00")
        XCTAssertEqual(value.regularReminder, date("2026-11-09 13:45:00"))
        XCTAssertEqual(value.catchUpReminder, date("2026-11-09 13:10:30"))
    }
    func testFiveMinutesUntilNormalReminderSkipsCatchUp() {
        let value = plan("2026-11-09 10:40:00")
        XCTAssertEqual(value.regularReminder, date("2026-11-09 10:45:00"))
        XCTAssertNil(value.catchUpReminder)
    }
    func testLessThanFiveMinutesSkipsCatchUp() {
        XCTAssertNil(plan("2026-11-09 10:44:59").catchUpReminder)
    }
    func testMoreThanFiveMinutesAllowsCatchUp() {
        XCTAssertNotNil(plan("2026-11-09 10:39:59").catchUpReminder)
    }
    func testShortIntervalNeverAddsCatchUp() {
        let short = ReminderSchedule(startMinute: 540, endMinute: 1260, intervalMinutes: 5)
        XCTAssertNil(plan("2026-11-09 10:21:00", schedule: short).catchUpReminder)
    }
    func testQuietHoursDiscardCatchUp() {
        let value = plan("2026-11-09 22:00:00")
        XCTAssertEqual(value.regularReminder, date("2026-11-10 09:00:00"))
        XCTAssertNil(value.catchUpReminder)
    }
    func testBufferCannotCrossEndOfWindow() {
        XCTAssertNil(plan("2026-11-09 20:59:45").catchUpReminder)
    }
    func testUnselectedDayDiscardsCatchUp() {
        let weekdays = ReminderSchedule(startMinute: 540, endMinute: 1260, intervalMinutes: 45, weekdays: .init([.monday]))
        let value = plan("2026-11-10 10:20:00", schedule: weekdays)
        XCTAssertEqual(value.regularReminder, date("2026-11-16 09:00:00"))
        XCTAssertNil(value.catchUpReminder)
    }
    func testEmptyWeekdaysPauseBothDeadlines() {
        let empty = ReminderSchedule(startMinute: 540, endMinute: 1260, intervalMinutes: 45, weekdays: [])
        let value = plan("2026-11-09 10:20:00", schedule: empty)
        XCTAssertNil(value.regularReminder)
        XCTAssertNil(value.catchUpReminder)
    }
    func testInterruptedReminderCanRecoverBeforeNextDue() {
        let value = plan("2026-11-09 10:10:00", due: "2026-11-09 10:45:00", interrupted: true)
        XCTAssertEqual(value.regularReminder, date("2026-11-09 10:45:00"))
        XCTAssertEqual(value.catchUpReminder, date("2026-11-09 10:10:30"))
    }
    func testInterruptedReminderAlsoObeysFiveMinuteRule() {
        XCTAssertNil(plan("2026-11-09 10:40:00", due: "2026-11-09 10:45:00", interrupted: true).catchUpReminder)
    }
    func testNewActiveWindowRestartsRegularCadenceAtItsStart() {
        XCTAssertEqual(plan("2026-11-10 10:20:00").regularReminder, date("2026-11-10 10:30:00"))
    }
    func testOvernightWindowBelongsToStartDay() {
        let night = ReminderSchedule(startMinute: 1320, endMinute: 120, intervalMinutes: 45, weekdays: [.monday])
        let value = plan("2026-11-10 00:20:00", due: "2026-11-09 23:30:00", schedule: night)
        XCTAssertEqual(value.regularReminder, date("2026-11-10 01:00:00"))
        XCTAssertNotNil(value.catchUpReminder)
    }
    func testAllDayPreservesPhaseAcrossMidnight() {
        let allDay = ReminderSchedule(startMinute: 0, endMinute: 0, intervalMinutes: 45, weekdays: [.monday, .tuesday])
        XCTAssertEqual(plan("2026-11-10 00:25:00", due: "2026-11-09 23:40:00", schedule: allDay).regularReminder,
                       date("2026-11-10 01:10:00"))
    }
}
