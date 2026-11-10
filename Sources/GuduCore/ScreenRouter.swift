import CoreGraphics
import Foundation

public enum ScreenRouter {
    /// AppKit mouse coordinates and NSScreen.frame use the same global space,
    /// including negative origins. Fall back to all screens if no frame matches.
    public static func targetIndices(
        cursor: CGPoint,
        frames: [CGRect],
        mode: DisplayMode
    ) -> [Int] {
        guard mode == .cursor,
              let index = frames.firstIndex(where: { $0.contains(cursor) }) else {
            return Array(frames.indices)
        }
        return [index]
    }
}
