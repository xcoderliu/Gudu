import CoreGraphics
import Foundation

/// Bean mascot and cup share one motion plan. A fixed-length, two-bone arm bends
/// at the elbow instead of stretching to follow an unreachable glass.
public struct DrinkingBodyPose: Sendable {
    public static let upperArmLength: CGFloat = 36
    public static let forearmLength: CGFloat = 34

    public let positionX: CGFloat
    public let sway: CGFloat
    public let stride: CGFloat
    public let cupCenter: CGPoint
    public let mouth: CGPoint
    public let cupLip: CGPoint
    public let grip: CGPoint
    public let shoulder: CGPoint
    public let elbow: CGPoint
    public let wrist: CGPoint

    public init(timeline: DrinkingTimeline) {
        let carry = timeline.carry
        // Finish walking within a comfortable arm's reach before reaching out.
        positionX = CGFloat(684 - 277 * timeline.approach + 277 * carry)
        let walking = sin(.pi * timeline.approach) + sin(.pi * carry)
        sway = CGFloat(sin(timeline.time * 10) * walking * 2 - timeline.relaxed * 2)
        stride = CGFloat(sin(timeline.time * 10) * walking * 12)

        mouth = CGPoint(x: positionX - 35, y: 235 + sway)
        let angle = timeline.tilt * 49 * .pi / 180
        let rimOffset = CGPoint(x: 27 * cos(angle) + 39 * sin(angle),
                                y: 27 * sin(angle) - 39 * cos(angle))
        let carried = CGPoint(
            x: 238 + 46 * timeline.arrival + 277 * carry + 33 * carry * carry * carry - 8 * timeline.withdraw,
            y: 291 - 20 * carry - sin(carry * .pi) * 8 + 20 * timeline.lower)
        let sip = timeline.tilt * carry
        // Rotate the same rim point into the mouth, rather than lifting a glass
        // toward the old human head. The small mascot can keep its short arms.
        cupCenter = CGPoint(x: carried.x + (mouth.x - rimOffset.x - carried.x) * sip,
                            y: carried.y + (mouth.y - rimOffset.y - carried.y) * sip)
        cupLip = CGPoint(x: cupCenter.x + rimOffset.x, y: cupCenter.y + rimOffset.y)
        grip = CGPoint(
            x: cupCenter.x + CGFloat(23 * cos(angle) - 7 * sin(angle)),
            y: cupCenter.y + CGFloat(23 * sin(angle) + 7 * cos(angle))
        )
        shoulder = CGPoint(x: positionX - 57, y: 267 + sway)
        let rest = CGPoint(x: positionX - 80, y: 315 + sway)
        let reach = CGFloat(timeline.pickup)
        let target = CGPoint(x: rest.x + (grip.x - rest.x) * reach,
                             y: rest.y + (grip.y - rest.y) * reach)
        let joints = Self.solveArm(shoulder: shoulder, target: target)
        elbow = joints.elbow
        wrist = joints.wrist
    }

    private static func solveArm(shoulder: CGPoint, target: CGPoint) -> (elbow: CGPoint, wrist: CGPoint) {
        let dx = target.x - shoulder.x
        let dy = target.y - shoulder.y
        let requested = max(sqrt(dx * dx + dy * dy), 0.001)
        let distance = min(max(requested, abs(upperArmLength - forearmLength) + 0.001),
                           upperArmLength + forearmLength - 0.001)
        let ux = dx / requested
        let uy = dy / requested
        let projection = (upperArmLength * upperArmLength - forearmLength * forearmLength + distance * distance) / (2 * distance)
        let height = sqrt(max(0, upperArmLength * upperArmLength - projection * projection))
        // Keep the same bend direction throughout the gesture, including the sip.
        let elbow = CGPoint(x: shoulder.x + ux * projection + uy * height,
                            y: shoulder.y + uy * projection - ux * height)
        let wrist = CGPoint(x: shoulder.x + ux * distance, y: shoulder.y + uy * distance)
        return (elbow, wrist)
    }
}
