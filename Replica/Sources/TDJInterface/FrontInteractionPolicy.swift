import Foundation
import CoreGraphics

enum FrontLibraryPresentation: Equatable {
    case content, loading, empty, noMatches, failed(String)

    static func resolve(count: Int, catalogueReady: Bool, catalogueRefreshing: Bool,
                        projecting: Bool, requestReady: Bool, hasQuery: Bool, error: String?) -> Self {
        if count > 0 { return .content }
        if catalogueRefreshing || projecting || !requestReady { return .loading }
        if let error { return .failed(error) }
        if !catalogueReady { return .loading }
        return hasQuery ? .noMatches : .empty
    }
}

enum FrontDeckSwipeDirection { case previous, next }

enum FrontDeckSwipePolicy {
    static func direction(horizontal: Double, vertical: Double, velocity: Double) -> FrontDeckSwipeDirection? {
        guard horizontal.isFinite, vertical.isFinite, velocity.isFinite,
              abs(horizontal) > abs(vertical) * 1.4,
              abs(horizontal) >= 60 || (abs(horizontal) >= 16 && velocity * horizontal > 0 && abs(velocity) >= 600) else { return nil }
        return horizontal < 0 ? .next : .previous
    }

    static func allowsStart(at point: CGPoint, bounds: CGRect, protected regions: [CGRect]) -> Bool {
        bounds.contains(point) && !regions.contains { !$0.isEmpty && $0.contains(point) }
    }
}
