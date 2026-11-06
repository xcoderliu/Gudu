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
}
