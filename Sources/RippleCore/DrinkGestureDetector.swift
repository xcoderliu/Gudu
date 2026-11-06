import Foundation

public struct DrinkGestureSample: Sendable {
    public var faceCount: Int
    public var hasRememberedMouth: Bool
    public var vesselConfidence: Double
    public var corroboratingVesselConfidence: Double
    public var hasHandNearMouth: Bool

    public init(faceCount: Int = 1, hasRememberedMouth: Bool = false, vesselConfidence: Double,
                corroboratingVesselConfidence: Double = 0, hasHandNearMouth: Bool = false) {
        self.faceCount = faceCount
        self.hasRememberedMouth = hasRememberedMouth
        self.vesselConfidence = vesselConfidence
        self.corroboratingVesselConfidence = corroboratingVesselConfidence
        self.hasHandNearMouth = hasHandNearMouth
    }
}

public enum DrinkVerificationStage: Sendable, Equatable {
    case findingFace, multiplePeople, bringCup, holding, verified
}

public struct DrinkVerificationProgress: Sendable, Equatable {
    public let stage: DrinkVerificationStage
    public let fraction: Double
    public let isHandAssisted: Bool
    public var isVerified: Bool { stage == .verified }

    public init(stage: DrinkVerificationStage, fraction: Double = 0, isHandAssisted: Bool = false) {
        self.stage = stage
        self.fraction = min(max(fraction, 0), 1)
        self.isHandAssisted = isHandAssisted
    }
}

/// Locate the mouth once, then accumulate cup evidence at that remembered place.
/// Losing face detection or temporarily missing a cup pauses progress, never
/// reverses it. A new camera session explicitly starts a new detector.
public struct DrinkGestureDetector: Sendable {
    public static let requiredEvidenceDuration: TimeInterval = 1.2
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
        let evidence = DrinkingVesselEvidence(cropConfidences: [sample.vesselConfidence, sample.corroboratingVesselConfidence])
        let weight = evidence.weight(handNearMouth: sample.hasHandNearMouth)
        guard weight > 0 else {
            return set(.bringCup)
        }
        holding += delta * weight
        if holding >= Self.requiredEvidenceDuration { return set(.verified, assisted: weight < 1) }
        return set(.holding, assisted: weight < 1)
    }

    private mutating func set(_ stage: DrinkVerificationStage, assisted: Bool = false) -> DrinkVerificationProgress {
        progress = DrinkVerificationProgress(stage: stage, fraction: stage == .verified ? 1 : holding / Self.requiredEvidenceDuration,
                                            isHandAssisted: assisted)
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
