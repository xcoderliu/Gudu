import Foundation

public enum DrinkingVesselLabels {
    // Exact Vision Revision 1 labels. Substrings would accept cupcake,
    // eyeglasses, porcupine, etc., causing false confirmations.
    public static let accepted: Set<String> = ["cup", "mug", "drinking_glass", "bottle", "jug"]
    public static func accepts(_ identifier: String) -> Bool { accepted.contains(identifier) }
}
