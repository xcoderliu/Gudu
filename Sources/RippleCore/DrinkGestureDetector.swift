import Foundation

public struct DrinkGestureSample: Sendable {
    public var faceCount: Int
    public var faceConfidence: Double
    /// The vessel classifier runs only in a tightly cropped mouth region.
    public var vesselConfidence: Double

    public init(faceCount: Int = 1, faceConfidence: Double = 1, vesselConfidence: Double) {
        self.faceCount = faceCount
        self.faceConfidence = faceConfidence
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

/// A conservative gesture heuristic, not proof that liquid was swallowed.
/// A vessel must stay in the mouth region for about a second; no lowering step.
public struct DrinkGestureDetector: Sendable {
    public private(set) var progress = DrinkVerificationProgress(stage: .findingFace)
    private var lastTime: TimeInterval?
    private var lastFaceTime: TimeInterval?
    private var lastVesselTime: TimeInterval?
    private var holding = 0.0

    public init() {}

    @discardableResult
    public mutating func consume(_ sample: DrinkGestureSample, at time: TimeInterval) -> DrinkVerificationProgress {
        guard !progress.isVerified, time.isFinite, time >= 0 else { return progress }
        if let lastTime, time <= lastTime { return progress }
        let gap = lastTime.map { time - $0 } ?? 0
        if gap > 0.75 { resetGesture() }
        let delta = gap > 0.75 ? 0 : min(gap, 0.25)
        lastTime = time

        guard sample.faceCount == 1, sample.faceConfidence.isFinite, sample.faceConfidence >= 0.5 else {
            if sample.faceCount > 1 || time - (lastFaceTime ?? -.infinity) > 0.5 { resetGesture() }
            return set(sample.faceCount > 1 ? .multiplePeople : .findingFace)
        }
        lastFaceTime = time
        guard sample.vesselConfidence.isFinite && sample.vesselConfidence >= 0.22 else {
            if time - (lastVesselTime ?? -.infinity) > 0.25 { holding = 0 }
            return set(.bringCup)
        }
        lastVesselTime = time
        holding += delta
        if holding >= 0.8 { return set(.verified, fraction: 1) }
        return set(.holding, fraction: holding / 0.8)
    }

    private mutating func resetGesture() {
        holding = 0
        lastFaceTime = nil; lastVesselTime = nil
    }

    private mutating func set(_ stage: DrinkVerificationStage, fraction: Double = 0) -> DrinkVerificationProgress {
        progress = DrinkVerificationProgress(stage: stage, fraction: fraction)
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
