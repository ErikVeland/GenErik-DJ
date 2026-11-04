import Foundation

/// A vertical touch move must not overwrite an X value changed by hardware in the meantime.
struct TouchAxisSession {
    private var previous: SurfacePoint?
    mutating func updatesX(_ event: SurfaceEvent) -> Bool {
        guard event.phase != .cancelled, let point = event.remaining.first else {
            previous = nil
            return false
        }
        let changed = previous?.id != point.id || previous?.x != point.x
        previous = point
        return changed
    }
}
