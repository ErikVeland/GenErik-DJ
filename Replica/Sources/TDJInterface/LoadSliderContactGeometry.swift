import CoreGraphics
import Foundation

/// A held loader uses its original global frame until release or cancellation.
struct LoadSliderContactGeometry {
    private var frame: CGRect?
    var height: Double { Double(frame?.height ?? 0) }
    mutating func begin(frame: CGRect) -> Bool {
        guard self.frame == nil, frame.width > 0, frame.height > 0,
            [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
        else { return false }
        self.frame = frame
        return true
    }
    func point(at location: CGPoint) -> SurfacePoint? {
        guard let frame, location.x.isFinite, location.y.isFinite else { return nil }
        return SurfacePoint(
            id: 1, x: (location.x - frame.minX) / frame.width, y: (location.y - frame.minY) / frame.height)
    }
    mutating func cancel() { frame = nil }
}
