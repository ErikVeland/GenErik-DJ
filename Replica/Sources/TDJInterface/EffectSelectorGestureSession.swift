import Foundation

/// A selector belongs to its initiating contact; hold timing uses a monotonic clock.
struct EffectSelectorGestureSession {
    var opened = false
    private var owner: Int?
    private var beganAt = 0.0
    private var dragged = false
    private var waitingForRelease = false
    private var opensOnTap = true
    var isTracking: Bool { owner != nil || waitingForRelease }
    mutating func dismiss() {
        waitingForRelease = isTracking
        owner = nil
        opened = false
    }
    mutating func handle(_ event: SurfaceEvent, at time: Double, count: Int, tapOpensMenu: Bool = true) -> Int? {
        if event.phase == .cancelled {
            self = Self()
            return nil
        }
        if waitingForRelease {
            if event.remaining.isEmpty { waitingForRelease = false }
            return nil
        }
        if owner == nil, event.phase == .began, let point = event.remaining.first {
            owner = point.id
            beganAt = time
            dragged = false
            opensOnTap = tapOpensMenu
        }
        guard let owner, let point = event.points.first(where: { $0.id == owner }) else { return nil }
        if event.phase == .moved, time - beganAt >= 0.3, point.y > 1 {
            opened = true
            dragged = true
        }
        guard event.phase == .ended, event.ending.contains(owner) else { return nil }
        self.owner = nil
        waitingForRelease = !event.remaining.isEmpty
        if dragged {
            opened = false
            let position = floor(point.y - 1)
            guard position.isFinite, position >= 0, position < Double(count) else { return nil }
            return Int(position)
        }
        if opensOnTap { opened.toggle() } else { opened = false }
        return nil
    }
}
