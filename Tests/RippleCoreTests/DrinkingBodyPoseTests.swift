import CoreGraphics
import XCTest
@testable import RippleCore

final class DrinkingBodyPoseTests: XCTestCase {
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    func testArmSegmentsKeepTheirLengthThroughoutTheRitual() {
        for frame in 0..<1800 {
            let pose = DrinkingBodyPose(timeline: DrinkingTimeline(elapsed: Double(frame) / 120))
            XCTAssertEqual(distance(pose.shoulder, pose.elbow), DrinkingBodyPose.upperArmLength, accuracy: 0.0001)
            XCTAssertEqual(distance(pose.elbow, pose.wrist), DrinkingBodyPose.forearmLength, accuracy: 0.0001)
        }
    }

    func testCupIsWithinReachAndHandRemainsAttachedAfterPickup() {
        for frame in 294..<900 {
            let pose = DrinkingBodyPose(timeline: DrinkingTimeline(elapsed: Double(frame) / 60))
            XCTAssertLessThan(distance(pose.shoulder, pose.grip), DrinkingBodyPose.upperArmLength + DrinkingBodyPose.forearmLength)
            XCTAssertEqual(distance(pose.wrist, pose.grip), 0, accuracy: 0.0001)
        }
    }

    func testWalkingStopsBeforeReachAndGraspFinishesBeforeCarry() {
        for frame in 0..<900 {
            let timeline = DrinkingTimeline(elapsed: Double(frame) / 60)
            if timeline.pickup > 0 { XCTAssertEqual(timeline.approach, 1) }
            if timeline.carry > 0 {
                XCTAssertEqual(timeline.pickup, 1)
                XCTAssertEqual(timeline.grasp, 1)
            }
        }
    }

    func testHandRotatesAroundGlassDuringSip() {
        let upright = DrinkingBodyPose(timeline: DrinkingTimeline(elapsed: 6.5))
        let tilted = DrinkingBodyPose(timeline: DrinkingTimeline(elapsed: 8.2))
        XCTAssertEqual(distance(upright.wrist, upright.cupCenter), distance(tilted.wrist, tilted.cupCenter), accuracy: 0.0001)
        XCTAssertLessThan(tilted.wrist.x - tilted.cupCenter.x, upright.wrist.x - upright.cupCenter.x)
        XCTAssertGreaterThan(tilted.wrist.y - tilted.cupCenter.y, upright.wrist.y - upright.cupCenter.y)
    }

    func testCupRimMeetsTheBeanMouthThroughoutTheFullSip() {
        for frame in 426...528 {
            let pose = DrinkingBodyPose(timeline: DrinkingTimeline(elapsed: Double(frame) / 60))
            XCTAssertEqual(distance(pose.cupLip, pose.mouth), 0, accuracy: 0.0001)
        }
    }

    func testElbowDoesNotJumpWhenReachingLiftingOrLowering() {
        var previous = DrinkingBodyPose(timeline: DrinkingTimeline(elapsed: 0))
        for frame in 1..<1800 {
            let pose = DrinkingBodyPose(timeline: DrinkingTimeline(elapsed: Double(frame) / 120))
            XCTAssertLessThan(distance(previous.elbow, pose.elbow), 3, "Elbow jumped at frame \(frame)")
            previous = pose
        }
    }
}
