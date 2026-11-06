import XCTest
@testable import RippleCore

final class DrinkingTimelineTests: XCTestCase {
    func testChoreographyPhases() {
        XCTAssertEqual(DrinkingTimeline(elapsed: 0.5).phase, .arrive)
        XCTAssertEqual(DrinkingTimeline(elapsed: 3).phase, .fill)
        XCTAssertEqual(DrinkingTimeline(elapsed: 5.5).phase, .carry)
        XCTAssertEqual(DrinkingTimeline(elapsed: 8).phase, .drink)
        XCTAssertEqual(DrinkingTimeline(elapsed: 12).phase, .relax)
    }

    func testCupFillsBeforeBeingCarriedAndEmptiesAfterDrinking() {
        let filled = DrinkingTimeline(elapsed: 4.7)
        XCTAssertEqual(filled.water, 1)
        XCTAssertEqual(filled.carry, 0)
        XCTAssertEqual(filled.stream, 0)
        XCTAssertEqual(DrinkingTimeline(elapsed: 9.4).water, 0)
        XCTAssertEqual(DrinkingTimeline(elapsed: 11).lower, 1)
    }

    func testSeamlessCycleResetsPose() {
        XCTAssertEqual(DrinkingTimeline(elapsed: 15.5).time, 0.5, accuracy: 0.0001)
        XCTAssertEqual(DrinkingTimeline(elapsed: 15).opacity, 0)
        XCTAssertEqual(DrinkingTimeline(elapsed: -1).time, 0)
    }

    func testReducedMotionHasStableSatisfiedPose() {
        let pose = DrinkingTimeline(elapsed: 0, still: true)
        XCTAssertEqual(pose.time, DrinkingTimeline(elapsed: 500, still: true).time)
        XCTAssertEqual(pose.relaxed, 1)
        XCTAssertEqual(pose.water, 0)
        XCTAssertEqual(pose.opacity, 1)
    }
}
