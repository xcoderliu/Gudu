import XCTest
@testable import RippleCore

final class DrinkGestureDetectorTests: XCTestCase {
    private func run(_ detector: inout DrinkGestureDetector, from start: Int, through end: Int,
                     confidence: Double = 0.8, faceCount: Int = 1, remembered: Bool = true) {
        for frame in start...end {
            detector.consume(DrinkGestureSample(faceCount: faceCount, hasRememberedMouth: remembered,
                                                vesselConfidence: confidence), at: Double(frame) / 10)
        }
    }

    func testCupAtMouthCompletesWithoutLowering() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 14)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testRequiresOnePointTwoSecondsOfCupEvidence() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 11)
        XCTAssertFalse(detector.progress.isVerified, "The previous shorter hold must not complete a drink")
        XCTAssertEqual(detector.progress.fraction, 1.1 / 1.2, accuracy: 0.0001)
        run(&detector, from: 12, through: 12, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testCannotCompleteBeforeMouthWasLocated() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 30, faceCount: 0, remembered: false)
        XCTAssertEqual(detector.progress.stage, .findingFace)
    }

    func testFacePresenceAloneDoesNotReplaceMouthCalibration() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 30, remembered: false)
        XCTAssertFalse(detector.progress.isVerified)
    }

    func testCupCoveringEntireFaceStillCompletes() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 0, confidence: 0)
        run(&detector, from: 1, through: 14, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testOnlyTheFirstFrameNeedsMouthCalibration() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 0, confidence: 0)
        run(&detector, from: 1, through: 14, faceCount: 0, remembered: false)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testRememberedMouthHasNoFaceLossTimeout() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 0, confidence: 0)
        run(&detector, from: 100, through: 114, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testLosingFaceNeverReducesProgress() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 4)
        let held = detector.progress.fraction
        XCTAssertGreaterThan(held, 0)
        run(&detector, from: 5, through: 20, confidence: 0, faceCount: 0)
        XCTAssertEqual(detector.progress.fraction, held)
        XCTAssertEqual(detector.progress.stage, .bringCup)
        run(&detector, from: 21, through: 30, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testMissedCupClassificationPausesInsteadOfResetting() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 4)
        let held = detector.progress.fraction
        run(&detector, from: 5, through: 100, confidence: 0)
        XCTAssertEqual(detector.progress.fraction, held)
        run(&detector, from: 101, through: 110)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testNoCupNeverCompletes() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 40, confidence: 0)
        XCTAssertEqual(detector.progress.fraction, 0)
        XCTAssertFalse(detector.progress.isVerified)
    }

    func testLowAndInvalidCupConfidenceNeverCompletes() {
        for confidence in [0.15, Double.nan, .infinity] {
            var detector = DrinkGestureDetector()
            run(&detector, from: 0, through: 40, confidence: confidence)
            XCTAssertFalse(detector.progress.isVerified)
        }
    }

    func testFrameGapNeitherAddsUnseenTimeNorClearsProgress() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 3)
        let held = detector.progress.fraction
        run(&detector, from: 100, through: 100, faceCount: 0)
        XCTAssertEqual(detector.progress.fraction, held)
        XCTAssertFalse(detector.progress.isVerified)
        run(&detector, from: 101, through: 111, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testStaleAndInvalidTimestampsDoNotAdvanceProgress() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 3)
        let before = detector.progress
        for time in [-1, 0.1, 0.3, Double.nan, .infinity] {
            detector.consume(DrinkGestureSample(hasRememberedMouth: true, vesselConfidence: 0.8), at: time)
            XCTAssertEqual(detector.progress, before)
        }
    }

    func testMultiplePeopleCannotSupplyInitialMouthLocation() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 10, faceCount: 2, remembered: false)
        XCTAssertEqual(detector.progress.stage, .multiplePeople)
    }

    func testFaceCountDoesNotResetAnAlreadyKnownMouth() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 3)
        let held = detector.progress.fraction
        run(&detector, from: 4, through: 10, confidence: 0, faceCount: 2)
        XCTAssertEqual(detector.progress.fraction, held)
        run(&detector, from: 11, through: 22, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testVerificationIsTerminal() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 14)
        run(&detector, from: 15, through: 30, confidence: 0, faceCount: 0)
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
