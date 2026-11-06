import Foundation
import XCTest
@testable import RippleCore

final class SettingsPersistenceTests: XCTestCase {
    func testOldPreferencesKeepValuesWhenCharacterIsMissing() throws {
        let old = Data(#"{"intervalMinutes":30,"startMinute":480,"endMinute":1200,"isEnabled":false,"displayMode":"all","soundEnabled":true,"autoDismissSeconds":60,"servingML":300,"dailyGoalML":2500}"#.utf8)
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: old)
        XCTAssertEqual(settings.character, .neutral)
        XCTAssertEqual(settings.intervalMinutes, 30)
        XCTAssertEqual(settings.startMinute, 480)
        XCTAssertEqual(settings.displayMode, .all)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.servingML, 300)
    }

    func testEveryCharacterRoundTripsAndDoesNotResetSchedule() throws {
        for character in ReminderCharacter.allCases {
            var settings = ReminderSettings(intervalMinutes: 30)
            let before = settings
            settings.character = character
            XCTAssertTrue(settings.hasSameSchedule(as: before))
            let data = try JSONEncoder().encode(settings)
            XCTAssertEqual(try JSONDecoder().decode(ReminderSettings.self, from: data), settings)
        }
    }

    func testPartialPreferencesSupplyDefaultsAndNormalize() throws {
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"intervalMinutes":-1,"character":"woman"}"#.utf8))
        XCTAssertEqual(settings.intervalMinutes, 1)
        XCTAssertEqual(settings.character, .woman)
        XCTAssertEqual(settings.dailyGoalML, 2000)
    }
}
