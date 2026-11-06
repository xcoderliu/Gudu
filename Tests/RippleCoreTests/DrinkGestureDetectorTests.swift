import XCTest
@testable import RippleCore

final class DrinkGestureDetectorTests: XCTestCase {
    private func run(_ detector: inout DrinkGestureDetector, from start: Int, through end: Int,
                     confidence: Double = 0.8, faceCount: Int = 1, faceConfidence: Double = 1) {
        for frame in start...end {
            detector.consume(DrinkGestureSample(faceCount: faceCount, faceConfidence: faceConfidence,
                                                vesselConfidence: confidence), at: Double(frame) / 10)
        }
    }

    func testCupAtMouthCompletesWithoutBaselineOrLowering() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 10)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testBriefCupSightingDoesNotComplete() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 4)
        XCTAssertFalse(detector.progress.isVerified)
        run(&detector, from: 5, through: 15, confidence: 0)
        run(&detector, from: 16, through: 19)
        XCTAssertFalse(detector.progress.isVerified)
    }

    func testEmptyMouthRegionNeverCompletes() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 40, confidence: 0)
        XCTAssertEqual(detector.progress.stage, .bringCup)
    }

    func testLowClassifierConfidenceDoesNotComplete() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 40, confidence: 0.15)
        XCTAssertFalse(detector.progress.isVerified)
    }

    func testMissingFaceCannotCompleteAndResetsHeldTime() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 4)
        run(&detector, from: 5, through: 15, faceCount: 0)
        run(&detector, from: 16, through: 19)
        XCTAssertFalse(detector.progress.isVerified)
    }

    func testMultiplePeopleResetTheCurrentAttempt() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 4)
        run(&detector, from: 5, through: 6, faceCount: 2)
        XCTAssertEqual(detector.progress.stage, .multiplePeople)
        run(&detector, from: 7, through: 11)
        XCTAssertFalse(detector.progress.isVerified)
    }

    func testLowOrInvalidFaceConfidenceCannotComplete() {
        for confidence in [0.3, Double.nan, .infinity] {
            var detector = DrinkGestureDetector()
            run(&detector, from: 0, through: 30, faceConfidence: confidence)
            XCTAssertFalse(detector.progress.isVerified)
        }
    }

    func testLongFrameGapDoesNotCountAsViewingTime() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 3)
        run(&detector, from: 50, through: 55)
        XCTAssertFalse(detector.progress.isVerified)
        run(&detector, from: 56, through: 60)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testStaleAndInvalidTimestampsDoNotAdvanceProgress() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 3)
        let before = detector.progress
        for time in [-1, 0.1, 0.3, Double.nan, .infinity] {
            detector.consume(DrinkGestureSample(vesselConfidence: 0.8), at: time)
            XCTAssertEqual(detector.progress, before)
        }
    }

    func testVerificationIsTerminal() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 10)
        run(&detector, from: 11, through: 30, confidence: 0, faceCount: 2)
        XCTAssertTrue(detector.progress.isVerified)
    }
}

final class DrinkingVesselLabelsTests: XCTestCase {
    func testAcceptsCupAndBottleIdentifiers() {
        for label in ["cup", "mug", "drinking_glass", "bottle", "jug"] {
            XCTAssertTrue(DrinkingVesselLabels.accepts(label))
        }
    }

    func testDoesNotMatchUnrelatedSubstrings() {
        for label in ["cupcake", "eyeglasses", "hourglass", "porcupine", "raw_glass", "sunglasses", "juggling", "drink"] {
            XCTAssertFalse(DrinkingVesselLabels.accepts(label))
        }
    }
}

final class ReminderCompletionGateTests: XCTestCase {
    func testForcedReminderCannotCompleteOrTimeoutBeforeVerification() {
        let gate = ReminderCompletionGate(requiresVerification: true)
        XCTAssertFalse(gate.allowsCompletion(verified: false))
        XCTAssertFalse(gate.allowsAutoDismiss)
        XCTAssertFalse(gate.allowsSnooze)
    }

    func testVerifiedForcedReminderCanComplete() {
        XCTAssertTrue(ReminderCompletionGate(requiresVerification: true).allowsCompletion(verified: true))
    }

    func testStandardReminderRetainsManualAndTimeoutBehavior() {
        let gate = ReminderCompletionGate(requiresVerification: false)
        XCTAssertTrue(gate.allowsCompletion(verified: false))
        XCTAssertTrue(gate.allowsAutoDismiss)
        XCTAssertTrue(gate.allowsSnooze)
    }
}
