import Foundation

public enum DisplayMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case cursor
    case all

    public var id: String { rawValue }
}

public struct ReminderSettings: Codable, Equatable, Sendable {
    public var intervalMinutes: Int
    public var startMinute: Int
    public var endMinute: Int
    public var isEnabled: Bool
    public var displayMode: DisplayMode
    public var soundEnabled: Bool
    public var autoDismissSeconds: Int
    public var servingML: Int
    public var dailyGoalML: Int
    public var requireDrinkVerification: Bool

    public init(
        intervalMinutes: Int = 45,
        startMinute: Int = 9 * 60,
        endMinute: Int = 21 * 60,
        isEnabled: Bool = true,
        displayMode: DisplayMode = .cursor,
        soundEnabled: Bool = false,
        autoDismissSeconds: Int = 30,
        servingML: Int = 250,
        dailyGoalML: Int = 2000,
        requireDrinkVerification: Bool = false
    ) {
        self.intervalMinutes = intervalMinutes
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.isEnabled = isEnabled
        self.displayMode = displayMode
        self.soundEnabled = soundEnabled
        self.autoDismissSeconds = autoDismissSeconds
        self.servingML = servingML
        self.dailyGoalML = dailyGoalML
        self.requireDrinkVerification = requireDrinkVerification
        normalize()
    }

    private enum CodingKeys: String, CodingKey {
        case intervalMinutes, startMinute, endMinute, isEnabled, displayMode
        case soundEnabled, autoDismissSeconds, servingML, dailyGoalML, requireDrinkVerification
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            intervalMinutes: try values.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 45,
            startMinute: try values.decodeIfPresent(Int.self, forKey: .startMinute) ?? 540,
            endMinute: try values.decodeIfPresent(Int.self, forKey: .endMinute) ?? 1260,
            isEnabled: try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true,
            displayMode: try values.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? .cursor,
            soundEnabled: try values.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false,
            autoDismissSeconds: try values.decodeIfPresent(Int.self, forKey: .autoDismissSeconds) ?? 30,
            servingML: try values.decodeIfPresent(Int.self, forKey: .servingML) ?? 250,
            dailyGoalML: try values.decodeIfPresent(Int.self, forKey: .dailyGoalML) ?? 2000,
            requireDrinkVerification: try values.decodeIfPresent(Bool.self, forKey: .requireDrinkVerification) ?? false
        )
    }

    public mutating func normalize() {
        intervalMinutes = min(max(intervalMinutes, 1), 240)
        startMinute = min(max(startMinute, 0), 1439)
        endMinute = min(max(endMinute, 0), 1439)
        autoDismissSeconds = [0, 15, 30, 60].contains(autoDismissSeconds) ? autoDismissSeconds : 30
        servingML = min(max(servingML, 50), 1000)
        dailyGoalML = min(max(dailyGoalML, 500), 5000)
    }

    public var schedule: ReminderSchedule {
        ReminderSchedule(startMinute: startMinute, endMinute: endMinute, intervalMinutes: intervalMinutes)
    }

    public func hasSameSchedule(as other: Self) -> Bool {
        intervalMinutes == other.intervalMinutes && startMinute == other.startMinute &&
        endMinute == other.endMinute && isEnabled == other.isEnabled
    }
}

public struct HydrationEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let amountML: Int

    public init(id: UUID = UUID(), date: Date = Date(), amountML: Int) {
        self.id = id
        self.date = date
        self.amountML = amountML
    }
}
