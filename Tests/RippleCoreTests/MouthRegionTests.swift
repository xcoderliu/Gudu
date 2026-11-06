import CoreGraphics
import XCTest
@testable import RippleCore

final class MouthRegionTests: XCTestCase {
    func testMouthRegionExcludesDistantDeskArea() throws {
        let region = try XCTUnwrap(MouthRegion.boundingBox(mouth: CGPoint(x: 0.5, y: 0.7), faceWidth: 0.2, imageAspectRatio: 1.3))
        XCTAssertTrue(region.contains(CGPoint(x: 0.5, y: 0.7)))
        XCTAssertFalse(region.contains(CGPoint(x: 0.5, y: 0.1)))
    }

    func testRegionsAtEveryCornerStayWithinVisionBounds() throws {
        for x in [0.01, 0.99] {
            for y in [0.01, 0.99] {
                let region = try XCTUnwrap(MouthRegion.boundingBox(mouth: CGPoint(x: x, y: y), faceWidth: 0.25, imageAspectRatio: 1.5))
                XCTAssertGreaterThanOrEqual(region.minX, 0)
                XCTAssertGreaterThanOrEqual(region.minY, 0)
                XCTAssertLessThanOrEqual(region.maxX, 1)
                XCTAssertLessThanOrEqual(region.maxY, 1)
            }
        }
    }

    func testAspectRatioCorrectsCropHeight() throws {
        let square = try XCTUnwrap(MouthRegion.boundingBox(mouth: CGPoint(x: 0.5, y: 0.7), faceWidth: 0.1, imageAspectRatio: 1))
        let wide = try XCTUnwrap(MouthRegion.boundingBox(mouth: CGPoint(x: 0.5, y: 0.7), faceWidth: 0.1, imageAspectRatio: 2))
        XCTAssertEqual(wide.width, square.width)
        XCTAssertEqual(wide.height, square.height * 2, accuracy: 0.0001)
    }

    func testInvalidGeometryDoesNotProduceAVisionRequest() {
        for width: CGFloat in [0, -1, .nan, .infinity] {
            XCTAssertNil(MouthRegion.boundingBox(mouth: CGPoint(x: 0.5, y: 0.5), faceWidth: width, imageAspectRatio: 1.5))
        }
        XCTAssertNil(MouthRegion.boundingBox(mouth: CGPoint(x: CGFloat.nan, y: 0.5), faceWidth: 0.2, imageAspectRatio: 1.5))
        XCTAssertNil(MouthRegion.boundingBox(mouth: CGPoint(x: 0.5, y: 0.5), faceWidth: 0.2, imageAspectRatio: 0))
    }

    func testAllThreeViewsContainTheRememberedMouth() {
        let mouth = CGPoint(x: 0.5, y: 0.65)
        let crops = MouthRegion.classificationCrops(mouth: mouth, faceWidth: 0.2, imageAspectRatio: 1.3)
        XCTAssertEqual(crops.map(\.kind), [.body, .rim, .tilted])
        XCTAssertTrue(crops.allSatisfy { $0.bounds.contains(mouth) })
    }

    func testRimViewExcludesTheLowerGrippingHand() throws {
        let crops = MouthRegion.classificationCrops(mouth: CGPoint(x: 0.5, y: 0.7), faceWidth: 0.2, imageAspectRatio: 1.3)
        let lowerGrip = CGPoint(x: 0.5, y: 0.52)
        XCTAssertTrue(try XCTUnwrap(crops.first { $0.kind == .body }).bounds.contains(lowerGrip))
        XCTAssertFalse(try XCTUnwrap(crops.first { $0.kind == .rim }).bounds.contains(lowerGrip))
    }

    func testTiltedViewIncludesCupAboveTheStandardCrop() throws {
        let crops = MouthRegion.classificationCrops(mouth: CGPoint(x: 0.5, y: 0.65), faceWidth: 0.2, imageAspectRatio: 1.3)
        let tiltedBase = CGPoint(x: 0.5, y: 0.81)
        XCTAssertFalse(try XCTUnwrap(crops.first { $0.kind == .body }).bounds.contains(tiltedBase))
        XCTAssertTrue(try XCTUnwrap(crops.first { $0.kind == .tilted }).bounds.contains(tiltedBase))
    }

    func testCropsAtImageEdgesStayClippedAndDistinct() {
        for mouth in [CGPoint(x: 0.01, y: 0.01), CGPoint(x: 0.99, y: 0.99)] {
            let crops = MouthRegion.classificationCrops(mouth: mouth, faceWidth: 0.25, imageAspectRatio: 1.5)
            for (index, crop) in crops.enumerated() {
                XCTAssertTrue(CGRect(x: 0, y: 0, width: 1, height: 1).contains(crop.bounds))
                XCTAssertFalse(crops.prefix(index).contains { $0.bounds == crop.bounds })
            }
        }
    }

    func testInvalidGeometryDoesNotProduceClassificationCrops() {
        XCTAssertTrue(MouthRegion.classificationCrops(mouth: CGPoint(x: 0.5, y: 0.5), faceWidth: 0, imageAspectRatio: 1.3).isEmpty)
        XCTAssertTrue(MouthRegion.classificationCrops(mouth: CGPoint(x: CGFloat.nan, y: 0.5), faceWidth: 0.2, imageAspectRatio: 1.3).isEmpty)
    }

    func testSeveralHandJointsNearTheMouthQualify() {
        let joints = [CGPoint(x: 0.48, y: 0.6), CGPoint(x: 0.5, y: 0.58), CGPoint(x: 0.52, y: 0.57)]
        XCTAssertTrue(MouthRegion.hasNearbyHand(joints: joints, mouth: CGPoint(x: 0.5, y: 0.7), faceWidth: 0.2, imageAspectRatio: 1.3))
    }

    func testOneOrTwoJointsDoNotSupplyHandSupport() {
        let joints = [CGPoint(x: 0.48, y: 0.6), CGPoint(x: 0.5, y: 0.58)]
        XCTAssertFalse(MouthRegion.hasNearbyHand(joints: joints, mouth: CGPoint(x: 0.5, y: 0.7), faceWidth: 0.2, imageAspectRatio: 1.3))
    }

    func testDistantOrInvalidHandJointsDoNotQualify() {
        let joints = [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.12, y: 0.1), CGPoint(x: 0.13, y: 0.12), CGPoint(x: CGFloat.nan, y: 0.6)]
        XCTAssertFalse(MouthRegion.hasNearbyHand(joints: joints, mouth: CGPoint(x: 0.5, y: 0.7), faceWidth: 0.2, imageAspectRatio: 1.3))
    }

}

final class MouthPositionMemoryTests: XCTestCase {
    private let face = CGRect(x: 0.35, y: 0.3, width: 0.3, height: 0.5)
    private let mouth = CGPoint(x: 0.5, y: 0.45)

    func testRemembersVisibleMouth() {
        var memory = MouthPositionMemory()
        XCTAssertTrue(memory.remember(face: face, mouth: mouth))
        XCTAssertEqual(memory.anchor?.mouth, mouth)
    }

    func testInvalidFaceDoesNotEraseLastMouth() {
        var memory = MouthPositionMemory()
        memory.remember(face: face, mouth: mouth)
        XCTAssertFalse(memory.remember(face: .null, mouth: CGPoint(x: CGFloat.nan, y: 0)))
        XCTAssertEqual(memory.anchor?.mouth, mouth)
    }

    func testUpdatesWhenAnUncoveredFaceMoves() {
        var memory = MouthPositionMemory()
        memory.remember(face: face, mouth: mouth)
        let moved = CGPoint(x: mouth.x + 0.1, y: mouth.y + 0.05)
        XCTAssertTrue(memory.remember(face: face.offsetBy(dx: 0.1, dy: 0.05), mouth: moved))
        XCTAssertEqual(memory.anchor?.mouth, moved)
    }

    func testSmallerWholeFaceCanUpdatePosition() {
        var memory = MouthPositionMemory()
        memory.remember(face: face, mouth: mouth)
        let smaller = CGRect(x: 0.4, y: 0.4, width: 0.15, height: 0.25)
        let updated = CGPoint(x: smaller.midX, y: smaller.minY + smaller.height * 0.3)
        XCTAssertTrue(memory.remember(face: smaller, mouth: updated))
        XCTAssertEqual(memory.anchor?.mouth, updated)
    }

    func testCupOcclusionDoesNotMoveMouthIntoUpperFace() {
        var memory = MouthPositionMemory()
        memory.remember(face: face, mouth: mouth)
        let partial = CGRect(x: face.minX, y: face.minY + face.height * 0.5,
                             width: face.width, height: face.height * 0.5)
        let wrong = CGPoint(x: partial.midX, y: partial.minY + partial.height * 0.3)
        XCTAssertFalse(memory.remember(face: partial, mouth: wrong))
        XCTAssertEqual(memory.anchor?.mouth, mouth)
    }

    func testExplicitResetClearsPositionForANewSession() {
        var memory = MouthPositionMemory()
        memory.remember(face: face, mouth: mouth)
        memory.reset()
        XCTAssertNil(memory.anchor)
    }
}
