import CoreGraphics
import Foundation

public enum MouthRegion {
    public static func boundingBox(mouth: CGPoint, faceWidth: CGFloat, imageAspectRatio: CGFloat) -> CGRect? {
        guard mouth.x.isFinite, mouth.y.isFinite, faceWidth.isFinite, imageAspectRatio.isFinite,
              (0...1).contains(mouth.x), (0...1).contains(mouth.y),
              faceWidth > 0, faceWidth <= 1, imageAspectRatio > 0 else { return nil }
        let height = faceWidth * imageAspectRatio * 1.3
        guard height.isFinite else { return nil }
        let region = CGRect(x: mouth.x - faceWidth * 0.85,
                            y: mouth.y - faceWidth * imageAspectRatio * 0.95,
                            width: faceWidth * 1.7, height: height)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !region.isNull, region.width > 0.02, region.height > 0.02 else { return nil }
        return region
    }
}
