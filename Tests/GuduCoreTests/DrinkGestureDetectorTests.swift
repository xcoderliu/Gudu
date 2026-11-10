import XCTest
@testable import GuduCore

final class DrinkGestureDetectorTests: XCTestCase {
    private func run(_ detector: inout DrinkGestureDetector, from start: Int, through end: Int,
                     confidence: Double = 0.8, faceCount: Int = 1, remembered: Bool = true,
                     corroborating: Double = 0, hand: Bool = false) {
        for frame in start...end {
            detector.consume(DrinkGestureSample(faceCount: faceCount, hasRememberedMouth: remembered,
                                                vesselConfidence: confidence, corroboratingVesselConfidence: corroborating,
                                                hasHandNearMouth: hand), at: Double(frame) / 10)
        }
    }

    func testCupAtMouthCompletesWithoutLowering() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 32)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testRequiresThreeSecondsOfCupEvidence() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 29)
        XCTAssertFalse(detector.progress.isVerified, "The previous shorter hold must not complete a drink")
        XCTAssertEqual(detector.progress.fraction, 2.9 / 3, accuracy: 0.0001)
        run(&detector, from: 30, through: 30, faceCount: 0)
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
        run(&detector, from: 1, through: 32, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testOnlyTheFirstFrameNeedsMouthCalibration() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 0, confidence: 0)
        run(&detector, from: 1, through: 32, faceCount: 0, remembered: false)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testRememberedMouthHasNoFaceLossTimeout() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 0, confidence: 0)
        run(&detector, from: 100, through: 132, faceCount: 0)
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
        run(&detector, from: 21, through: 49, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testMissedCupClassificationPausesInsteadOfResetting() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 4)
        let held = detector.progress.fraction
        run(&detector, from: 5, through: 100, confidence: 0)
        XCTAssertEqual(detector.progress.fraction, held)
        run(&detector, from: 101, through: 129)
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
        run(&detector, from: 101, through: 130, faceCount: 0)
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
        run(&detector, from: 11, through: 40, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testVerificationIsTerminal() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 32)
        run(&detector, from: 33, through: 50, confidence: 0, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testPartiallyCoveredCupUsesSlowerHandSupportedEvidenceWithoutFace() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 30, confidence: 0.16, faceCount: 0, corroborating: 0.09, hand: true)
        XCTAssertFalse(detector.progress.isVerified)
        XCTAssertTrue(detector.progress.isHandAssisted)
        XCTAssertEqual(detector.progress.fraction, 0.5, accuracy: 0.0001)
        run(&detector, from: 31, through: 59, confidence: 0.16, faceCount: 0, corroborating: 0.09, hand: true)
        XCTAssertFalse(detector.progress.isVerified)
        XCTAssertEqual(detector.progress.fraction, 5.9 / 6, accuracy: 0.0001)
        run(&detector, from: 60, through: 60, confidence: 0.16, faceCount: 0, corroborating: 0.09, hand: true)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testBareHandAtMouthCannotCompleteADrink() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 60, confidence: 0, faceCount: 0, hand: true)
        XCTAssertEqual(detector.progress.fraction, 0)
        XCTAssertFalse(detector.progress.isVerified)
    }

    func testWeakCupWithoutHandDoesNotComplete() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 60, confidence: 0.16, corroborating: 0.09)
        XCTAssertEqual(detector.progress.fraction, 0)
    }

    func testOneWeakCupCropAndAHandCannotComplete() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 60, confidence: 0.16, hand: true)
        XCTAssertEqual(detector.progress.fraction, 0)
    }

    func testLosingHandSupportPausesAndClearCupCanResume() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 10, confidence: 0.16, faceCount: 0, corroborating: 0.09, hand: true)
        let held = detector.progress.fraction
        run(&detector, from: 11, through: 30, confidence: 0.16, faceCount: 0, corroborating: 0.09)
        XCTAssertEqual(detector.progress.fraction, held)
        run(&detector, from: 31, through: 58, faceCount: 0)
        XCTAssertTrue(detector.progress.isVerified)
    }

    func testAssistedEvidenceStillRequiresInitialMouthLocation() {
        var detector = DrinkGestureDetector()
        run(&detector, from: 0, through: 60, confidence: 0.16, faceCount: 0, remembered: false,
            corroborating: 0.09, hand: true)
        XCTAssertEqual(detector.progress.stage, .findingFace)
        XCTAssertEqual(detector.progress.fraction, 0)
    }
}

final class DrinkingVesselLabelsTests: XCTestCase {
    func testAcceptsCupAndBottleIdentifiers() {
        for label in ["cup", "mug", "drinking_glass", "bottle", "jug", "thermos"] {
            XCTAssertTrue(DrinkingVesselLabels.accepts(label))
        }
    }

    func testDoesNotMatchUnrelatedSubstrings() {
        for label in ["cupcake", "eyeglasses", "hourglass", "porcupine", "raw_glass", "sunglasses", "juggling", "drink", "thermostat", "tea_drink", "straw_drinking"] {
            XCTAssertFalse(DrinkingVesselLabels.accepts(label))
        }
    }
}

final class DrinkingVesselEvidenceTests: XCTestCase {
    func testClearCupDoesNotNeedAHandOrSecondView() {
        XCTAssertEqual(DrinkingVesselEvidence(cropConfidences: [0.3]).weight(handNearMouth: false), 1)
    }

    func testTwoWeakViewsWithNearbyHandUseHalfWeight() {
        let evidence = DrinkingVesselEvidence(cropConfidences: [0.08, 0.16, 0.03])
        XCTAssertEqual(evidence.strongest, 0.16)
        XCTAssertEqual(evidence.corroborating, 0.08)
        XCTAssertEqual(evidence.weight(handNearMouth: true), 0.5)
    }

    func testWeakViewsAloneDoNotQualify() {
        XCTAssertEqual(DrinkingVesselEvidence(cropConfidences: [0.16, 0.08]).weight(handNearMouth: false), 0)
    }

    func testOneWeakViewIsNotCorroboration() {
        XCTAssertEqual(DrinkingVesselEvidence(cropConfidences: [0.16]).weight(handNearMouth: true), 0)
    }

    func testTwoVeryWeakViewsDoNotQualify() {
        for scores in [[0.09, 0.08], [0.18, 0.05]] {
            XCTAssertEqual(DrinkingVesselEvidence(cropConfidences: scores).weight(handNearMouth: true), 0)
        }
    }

    func testBareHandAndEmptyResultsDoNotQualify() {
        for scores: [Double] in [[], [0, 0, 0]] {
            XCTAssertEqual(DrinkingVesselEvidence(cropConfidences: scores).weight(handNearMouth: true), 0)
        }
    }

    func testInvalidScoresCannotCreateCupEvidence() {
        let evidence = DrinkingVesselEvidence(cropConfidences: [.nan, .infinity, -1, 1.2, 0.07])
        XCTAssertEqual(evidence.weight(handNearMouth: true), 0)
    }

    func testThresholdBoundaries() {
        XCTAssertEqual(DrinkingVesselEvidence(cropConfidences: [0.22]).weight(handNearMouth: false), 1)
        XCTAssertEqual(DrinkingVesselEvidence(cropConfidences: [0.10, 0.06]).weight(handNearMouth: true), 0.5)
    }
}

final class ReminderCompletionGateTests: XCTestCase {
    func testCameraUnavailableAllowsManualConfirmationWithoutAutoDismiss() {
        let gate = ReminderCompletionGate(requiresVerification: true, cameraUnavailable: true)
        XCTAssertFalse(gate.requiresVerification)
        XCTAssertTrue(gate.allowsCompletion(verified: false))
        XCTAssertTrue(gate.allowsSnooze)
        XCTAssertFalse(gate.allowsAutoDismiss)
    }

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
