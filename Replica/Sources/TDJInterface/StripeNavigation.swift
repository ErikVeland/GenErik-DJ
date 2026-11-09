import Foundation
import TDJCore

@MainActor final class StripeGestureSession {
    private struct Drag {
        let contact: Int
        let offset: Double
    }
    private struct Pinch {
        let first: Int
        let second: Int
        let distance: Double
        let seconds: Double
    }
    private var drag: Drag?
    private var pinch: Pinch?
    private var active = false
    private var ignoring = false
    private var load: UUID?
    private var center = 0.0
    private var wasPreviewing = false
    private var wasEditing = false
    private var wasFrozen = false

    func handle(
        _ event: SurfaceEvent, model: ReplicaModel, deck: DeckID, visibleSeconds: Double,
        width: Double, onZoom: (Double) -> Void
    ) {
        if ignoring {
            if event.remaining.isEmpty || event.phase == .cancelled { ignoring = false }
            return
        }
        guard let track = model.track(deck), track.analysis.frameCount > 0 else { return }
        if active, load != model.loadIdentity(deck) || wasEditing != model.editing.contains(deck)
            || wasFrozen != model.frozen.contains(deck)
        {
            reset()
            ignoring = !event.remaining.isEmpty && event.phase != .cancelled
            return
        }
        if event.phase == .cancelled {
            if active {
                if wasPreviewing || wasEditing || wasFrozen {
                    model.viewport[deck] = center
                    if !wasPreviewing { model.previewing.remove(deck) }
                } else {
                    model.returnToPlayhead(deck: deck)
                }
            }
            reset()
            return
        }
        guard event.points.allSatisfy({ $0.x.isFinite }), let first = event.points.first else { return }
        let frames = Double(track.analysis.frameCount)
        if !active {
            guard event.phase == .began else { return }
            active = true
            load = model.loadIdentity(deck)
            center = model.viewport[deck] ?? 0
            wasPreviewing = model.previewing.contains(deck)
            wasEditing = model.editing.contains(deck)
            wasFrozen = model.frozen.contains(deck)
            let halfWindow = max(10 / max(1, width), visibleSeconds / track.analysis.duration) / 2
            let offset = first.x - center / frames
            drag = Drag(contact: first.id, offset: abs(offset) <= halfWindow ? offset : 0)
            model.previewing.insert(deck)
        }
        defer { if event.phase == .ended && event.remaining.isEmpty { reset() } }
        if event.points.count > 2 {
            reset()
            ignoring = !event.remaining.isEmpty
            return
        }
        if event.points.count == 2 {
            if pinch == nil {
                pinch = Pinch(
                    first: event.points[0].id, second: event.points[1].id,
                    distance: max(0.01, abs(event.points[1].x - event.points[0].x)), seconds: visibleSeconds)
                drag = nil
            }
            if let pinch, let p = event.points.first(where: { $0.id == pinch.first }),
                let q = event.points.first(where: { $0.id == pinch.second })
            {
                let seconds = pinch.seconds * pinch.distance / max(0.01, abs(q.x - p.x))
                onZoom(max(min(1, track.analysis.duration), min(track.analysis.duration, seconds)))
            }
        } else if pinch == nil, let drag, let point = event.points.first(where: { $0.id == drag.contact }) {
            model.viewport[deck] = model.boundedFrame((point.x - drag.offset) * frames, deck: deck)
        }
        // A remaining pinch contact must not become a navigation drag.
        if pinch != nil, event.remaining.count < 2 {
            reset()
            ignoring = !event.remaining.isEmpty
        }
    }
    private func reset() {
        active = false
        drag = nil
        pinch = nil
    }
}
