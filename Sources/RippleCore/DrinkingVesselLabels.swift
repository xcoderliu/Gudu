import Foundation

public enum DrinkingVesselLabels {
    // Exact Vision Revision 1 labels. Substrings would accept cupcake,
    // eyeglasses, porcupine, etc., causing false confirmations.
    public static let accepted: Set<String> = ["cup", "mug", "drinking_glass", "bottle", "jug", "thermos"]
    public static func accepts(_ identifier: String) -> Bool { accepted.contains(identifier) }
}

/// Complementary views of the same mouth area can retain cup evidence when a
/// gripping hand dominates the larger crop. A hand by itself is never evidence.
public struct DrinkingVesselEvidence: Sendable, Equatable {
    public static let clearThreshold = 0.22
    public static let partialThreshold = 0.10
    public static let corroboratingThreshold = 0.06
    public let strongest: Double
    public let corroborating: Double

    public init(cropConfidences: [Double]) {
        let scores = cropConfidences.map { $0.isFinite && (0...1).contains($0) ? $0 : 0 }.sorted(by: >)
        strongest = scores.first ?? 0
        corroborating = scores.dropFirst().first ?? 0
    }

    public var isClear: Bool { strongest >= Self.clearThreshold }
    public var supportsHandAssistance: Bool {
        strongest >= Self.partialThreshold && corroborating >= Self.corroboratingThreshold
    }
    public func weight(handNearMouth: Bool) -> Double {
        if isClear { return 1 }
        return supportsHandAssistance && handNearMouth ? 0.5 : 0
    }
}
