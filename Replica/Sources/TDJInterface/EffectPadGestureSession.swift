import Foundation

/// A shared pad keeps its original slot until every contact ends or the surface cancels.
struct EffectPadGestureSession {
    private(set) var activeSlot: Int?
    private var axes = TouchAxisSession()
    struct Update {
        let slot: Int
        let updateX: Bool
    }
    mutating func handle(_ event: SurfaceEvent, selectedSlot: Int) -> Update? {
        if activeSlot == nil {
            guard event.phase == .began, !event.remaining.isEmpty, (0..<3).contains(selectedSlot) else { return nil }
            activeSlot = selectedSlot
        }
        guard let slot = activeSlot else { return nil }
        let update = Update(slot: slot, updateX: axes.updatesX(event))
        if event.phase == .cancelled || event.remaining.isEmpty { activeSlot = nil }
        return update
    }
    mutating func cancel() -> Int? {
        defer {
            activeSlot = nil
            axes = TouchAxisSession()
        }
        return activeSlot
    }
}
