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

struct FrontDeckSlideState {
    private(set) var position = 0.0
    private(set) var isDragging = false
    private(set) var isSettling = false
    private(set) var sessionID = UUID()
    private var originIsB = false
    private var width = 0.0
    private var horizontal = 0.0
    private var vertical = 0.0
    var blocksDeckInput: Bool { isDragging || isSettling }

    mutating func begin(selectedIsB: Bool, width: Double) -> Bool {
        guard !blocksDeckInput, width.isFinite, width > 0 else { return false }
        originIsB = selectedIsB
        self.width = width
        horizontal = 0
        vertical = 0
        position = selectedIsB ? 1 : 0
        isDragging = true
        return true
    }

    mutating func update(horizontal: Double, vertical: Double) {
        guard isDragging, horizontal.isFinite, vertical.isFinite else { return }
        self.horizontal = horizontal
        self.vertical = vertical
        position = min(1, max(0, (originIsB ? 1 : 0) - horizontal / width))
    }

    mutating func end(velocity: Double, settlementID: UUID) {
        guard isDragging else { return }
        let direction = FrontDeckSwipePolicy.direction(horizontal: horizontal, vertical: vertical, velocity: velocity)
        let reversed = velocity.isFinite && abs(velocity) >= 600 && velocity * horizontal < 0
        let target = reversed ? originIsB : direction.map { $0 == .next } ?? originIsB
        settle(on: target, settlementID: settlementID)
    }

    mutating func settle(on isB: Bool, settlementID: UUID) {
        sessionID = settlementID
        position = isB ? 1 : 0
        isDragging = false
        isSettling = true
    }

    mutating func complete(settlementID: UUID) -> Bool? {
        guard sessionID == settlementID, isSettling else { return nil }
        isSettling = false
        return position == 1
    }

    mutating func reset(selectedIsB: Bool) {
        sessionID = UUID()
        position = selectedIsB ? 1 : 0
        isDragging = false
        isSettling = false
    }

    func offset(isB: Bool, width: Double) -> Double {
        guard width.isFinite, width > 0 else { return 0 }
        return ((isB ? 1 : 0) - position) * width
    }
}
