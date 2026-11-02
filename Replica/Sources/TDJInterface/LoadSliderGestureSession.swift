import TDJCore

/// Keeps a cancelled load gesture from leaving an offset or loading a deck.
struct LoadSliderGestureSession {
    private var owner: Int?
    private var originY = 0.0
    private var waitingForRelease = false
    private(set) var offset = 0.0

    mutating func handle(_ event: SurfaceEvent, height: Double) -> DeckID? {
        if event.phase == .cancelled {
            self = Self()
            return nil
        }
        if waitingForRelease {
            if event.remaining.isEmpty { self = Self() }
            return nil
        }
        if owner == nil, event.phase == .began, let point = event.remaining.first {
            owner = point.id; originY = point.y
        }
        guard let owner, let point = event.points.first(where: { $0.id == owner }) else { return nil }
        let distance = (point.y - originY) * height
        offset = min(18,max(-18,distance))
        guard event.phase == .ended, event.ending.contains(owner) else { return nil }
        let destination: DeckID? = distance <= -16 ? .a : distance >= 16 ? .b : nil
        self = Self()
        waitingForRelease = !event.remaining.isEmpty
        return destination
    }
}
