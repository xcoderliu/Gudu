import Foundation

public struct DrinkGestureSample: Sendable {
    public var faceCount: Int
    public var hasRememberedMouth: Bool
    public var vesselConfidence: Double

    public init(faceCount: Int = 1, hasRememberedMouth: Bool = false, vesselConfidence: Double) {
        self.faceCount = faceCount
        self.hasRememberedMouth = hasRememberedMouth
        self.vesselConfidence = vesselConfidence
    }
}

public enum DrinkVerificationStage: Sendable, Equatable {
    case findingFace, multiplePeople, bringCup, holding, verified
}

public struct DrinkVerificationProgress: Sendable, Equatable {
    public let stage: DrinkVerificationStage
    public let fraction: Double
    public var isVerified: Bool { stage == .verified }

    public init(stage: DrinkVerificationStage, fraction: Double = 0) {
        self.stage = stage
        self.fraction = min(max(fraction, 0), 1)
    }
}

/// Locate the mouth once, then accumulate cup evidence at that remembered place.
/// Losing face detection or temporarily missing a cup pauses progress, never
/// reverses it. A new camera session explicitly starts a new detector.
public struct DrinkGestureDetector: Sendable {
    public private(set) var progress = DrinkVerificationProgress(stage: .findingFace)
    private var lastTime: TimeInterval?
    private var hasMouthLocation = false
    private var holding = 0.0

    public init() {}

    @discardableResult
    public mutating func consume(_ sample: DrinkGestureSample, at time: TimeInterval) -> DrinkVerificationProgress {
        guard !progress.isVerified, time.isFinite, time >= 0 else { return progress }
        if let lastTime, time <= lastTime { return progress }
        let gap = lastTime.map { time - $0 } ?? 0
        let delta = gap > 0.75 ? 0 : min(gap, 0.25)
        lastTime = time
        hasMouthLocation = hasMouthLocation || sample.hasRememberedMouth

        guard hasMouthLocation else {
            return set(sample.faceCount > 1 ? .multiplePeople : .findingFace)
        }
        guard sample.vesselConfidence.isFinite, sample.vesselConfidence >= 0.22 else {
            return set(.bringCup)
        }
        holding += delta
        if holding >= 0.8 { return set(.verified) }
        return set(.holding)
    }

    private mutating func set(_ stage: DrinkVerificationStage) -> DrinkVerificationProgress {
        progress = DrinkVerificationProgress(stage: stage, fraction: stage == .verified ? 1 : holding / 0.8)
        return progress
    }
}

public struct ReminderCompletionGate: Sendable {
    public let requiresVerification: Bool
    public init(requiresVerification: Bool) { self.requiresVerification = requiresVerification }
    public var allowsAutoDismiss: Bool { !requiresVerification }
    public var allowsSnooze: Bool { !requiresVerification }
    public func allowsCompletion(verified: Bool) -> Bool { !requiresVerification || verified }
}
