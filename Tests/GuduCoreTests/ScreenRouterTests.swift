import Foundation
import XCTest
@testable import GuduCore

final class ScreenRouterTests: XCTestCase {
    private let frames = [
        CGRect(x: 0, y: 0, width: 1512, height: 982),
        CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        CGRect(x: 0, y: 982, width: 2560, height: 1440)
    ]

    func testPrimaryScreen() {
        XCTAssertEqual(ScreenRouter.targetIndices(cursor: CGPoint(x: 200, y: 400), frames: frames, mode: .cursor), [0])
    }

    func testLeftDisplayWithNegativeOrigin() {
        XCTAssertEqual(ScreenRouter.targetIndices(cursor: CGPoint(x: -800, y: 200), frames: frames, mode: .cursor), [1])
    }

    func testDisplayAbovePrimary() {
        XCTAssertEqual(ScreenRouter.targetIndices(cursor: CGPoint(x: 300, y: 1300), frames: frames, mode: .cursor), [2])
    }

    func testExplicitAllScreenMode() {
        XCTAssertEqual(ScreenRouter.targetIndices(cursor: CGPoint(x: 200, y: 400), frames: frames, mode: .all), [0, 1, 2])
    }

    func testUnmatchedCursorFallsBackToEveryDisplay() {
        XCTAssertEqual(ScreenRouter.targetIndices(cursor: CGPoint(x: -800, y: -200), frames: frames, mode: .cursor), [0, 1, 2])
    }

    func testNoScreens() {
        XCTAssertTrue(ScreenRouter.targetIndices(cursor: .zero, frames: [], mode: .cursor).isEmpty)
    }

    func testSharedEdgeSelectsOneScreen() {
        XCTAssertEqual(ScreenRouter.targetIndices(cursor: CGPoint(x: 0, y: 500), frames: frames, mode: .cursor), [0])
    }
}
