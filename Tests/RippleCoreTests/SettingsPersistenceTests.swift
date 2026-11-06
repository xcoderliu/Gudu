import Foundation
import XCTest
@testable import RippleCore

final class SettingsPersistenceTests: XCTestCase {
    func testOldPreferencesKeepValues() throws {
        let old = Data(#"{"intervalMinutes":30,"startMinute":480,"endMinute":1200,"isEnabled":false,"displayMode":"all","soundEnabled":true,"autoDismissSeconds":60,"servingML":300,"dailyGoalML":2500}"#.utf8)
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: old)
        XCTAssertEqual(settings.intervalMinutes, 30)
        XCTAssertEqual(settings.startMinute, 480)
        XCTAssertEqual(settings.displayMode, .all)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.servingML, 300)
        XCTAssertFalse(settings.requireDrinkVerification)
    }

    func testLegacyCharacterValuesAreIgnoredWithoutResettingPreferences() throws {
        let expected = ReminderSettings(intervalMinutes: 30, startMinute: 480, endMinute: 1200,
                                        isEnabled: false, displayMode: .all, soundEnabled: true,
                                        autoDismissSeconds: 60, servingML: 300, dailyGoalML: 2500,
                                        requireDrinkVerification: true)
        for legacy: Any in ["neutral", "woman", "man", "retired-style", ["legacy": true], NSNull()] {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(expected)) as? [String: Any])
            json["character"] = legacy
            let restored = try JSONDecoder().decode(ReminderSettings.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertEqual(restored, expected)
        }
    }

    func testSavingSettingsDoesNotWriteTheRemovedCharacterField() throws {
        let settings = ReminderSettings(intervalMinutes: 30, soundEnabled: true, requireDrinkVerification: true)
        let data = try JSONEncoder().encode(settings)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["character"])
        XCTAssertEqual(try JSONDecoder().decode(ReminderSettings.self, from: data), settings)
    }

    func testPartialPreferencesSupplyDefaultsAndNormalize() throws {
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"intervalMinutes":-1,"character":"woman"}"#.utf8))
        XCTAssertEqual(settings.intervalMinutes, 1)
        XCTAssertEqual(settings.dailyGoalML, 2000)
    }

    func testCameraPreferenceRoundTripsWithoutResettingSchedule() throws {
        var settings = ReminderSettings(intervalMinutes: 30)
        let before = settings
        settings.requireDrinkVerification = true
        XCTAssertTrue(settings.hasSameSchedule(as: before))
        let restored = try JSONDecoder().decode(ReminderSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertTrue(restored.requireDrinkVerification)
    }
}
