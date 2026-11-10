import Foundation

/// One 15-second vector choreography, shared by every reminder display.
public struct DrinkingTimeline: Sendable {
    public static let duration = 15.0
    public enum Phase: Sendable { case arrive, fill, carry, drink, relax }
    public let time: Double

    public init(elapsed: TimeInterval, still: Bool = false) {
        time = still ? 11.7 : max(0, elapsed).truncatingRemainder(dividingBy: Self.duration)
    }

    public var phase: Phase {
        switch time {
        case ..<1.4: .arrive
        case ..<4.8: .fill
        case ..<6.8: .carry
        case ..<9.8: .drink
        default: .relax
        }
    }

    public var arrival: Double { ease(0.2, 1.2) }
    public var approach: Double { ease(0.8, 3.8) }
    public var pickup: Double { ease(3.95, 4.75) }
    public var grasp: Double { ease(4.75, 4.9) }
    public var carry: Double { ease(4.9, 6.7) }
    public var tilt: Double { ease(6.55, 7.1) * (1 - ease(8.8, 9.6)) }
    public var lower: Double { ease(9.5, 10.6) }
    public var withdraw: Double { ease(9.35, 10.05) }
    public var relaxed: Double { ease(10.4, 11.2) }
    public var water: Double { ease(1.4, 4.5) * (1 - ease(7.1, 9.1)) }
    public var stream: Double { ease(1.35, 1.6) * (1 - ease(4.25, 4.55)) }
    public var opacity: Double { ease(0, 0.35) * (1 - ease(14.2, 15)) }

    private func ease(_ start: Double, _ end: Double) -> Double {
        let progress = min(max((time - start) / (end - start), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }
}
