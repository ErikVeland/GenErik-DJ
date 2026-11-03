import TDJCore

/// Keeps a cancelled load gesture from leaving an offset or loading a deck.
struct LoadSliderGestureSession {
    private var owner: Int?
    private var originY = 0.0
    private var waitingForRelease = false
    private(set) var offset = 0.0
    private(set) var armedDeck: DeckID?

    mutating func handle(_ event: SurfaceEvent, height: Double, maximumTravel: Double = 18,
                         edgeTapThreshold: Double? = nil) -> DeckID? {
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
        let travel = max(2, maximumTravel)
        offset = min(travel,max(-travel,distance))
        let threshold = travel - 2
        armedDeck = distance <= -threshold ? .a : distance >= threshold ? .b : nil
        guard event.phase == .ended, event.ending.contains(owner) else { return nil }
        let edgeTap = edgeTapThreshold.flatMap { threshold -> DeckID? in
            guard abs(distance) < threshold * height else { return nil }
            if originY <= threshold { return .a }
            if originY >= 1 - threshold { return .b }
            return nil
        }
        let destination = armedDeck ?? edgeTap
        self = Self()
        waitingForRelease = !event.remaining.isEmpty
        return destination
    }
}
