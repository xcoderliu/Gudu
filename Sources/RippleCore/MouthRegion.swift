import CoreGraphics
import Foundation

public enum MouthRegion {
    public static func boundingBox(mouth: CGPoint, faceWidth: CGFloat, imageAspectRatio: CGFloat) -> CGRect? {
        guard mouth.x.isFinite, mouth.y.isFinite, faceWidth.isFinite, imageAspectRatio.isFinite,
              (0...1).contains(mouth.x), (0...1).contains(mouth.y),
              faceWidth > 0, faceWidth <= 1, imageAspectRatio > 0 else { return nil }
        let height = faceWidth * imageAspectRatio * 1.3
        guard height.isFinite else { return nil }
        let region = CGRect(x: mouth.x - faceWidth * 0.675,
                            y: mouth.y - faceWidth * imageAspectRatio * 0.95,
                            width: faceWidth * 1.35, height: height)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !region.isNull, region.width > 0.02, region.height > 0.02 else { return nil }
        return region
    }
}

public struct MouthAnchor: Sendable {
    public let mouth: CGPoint
    public let faceWidth: CGFloat
    public let face: CGRect
}

/// Coordinates live only for this camera session. They do not expire when a
/// drinking cup hides the face; explicit retry/stop creates a fresh memory.
public struct MouthPositionMemory: Sendable {
    public private(set) var anchor: MouthAnchor?

    public init() {}
    public mutating func reset() { anchor = nil }

    @discardableResult
    public mutating func remember(face: CGRect, mouth: CGPoint) -> Bool {
        guard !face.isNull, !face.isInfinite, face.minX.isFinite, face.minY.isFinite,
              face.width.isFinite, face.height.isFinite, face.width >= 0.06, face.height > 0,
              face.minX >= 0, face.minY >= 0, face.maxX <= 1, face.maxY <= 1,
              mouth.x.isFinite, mouth.y.isFinite, face.contains(mouth) else { return false }
        let relativeY = (mouth.y - face.minY) / face.height
        guard (0.05...0.55).contains(relativeY) else { return false }
        // A cup can make Vision return just the upper half of a face. Keep the
        // previous mouth instead of treating the bottom of that box as a mouth.
        if let anchor, face.height < anchor.face.height * 0.78,
           face.width > anchor.face.width * 0.7 { return false }
        anchor = MouthAnchor(mouth: mouth, faceWidth: face.width, face: face)
        return true
    }
}
