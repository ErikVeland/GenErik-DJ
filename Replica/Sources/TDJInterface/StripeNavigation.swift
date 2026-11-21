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
    private var wasReleased = false
    private var wasEditing = false
    private var wasFrozen = false
    private var stopped: (owner: UUID, generation: UInt64)?
    private var initialPresentation: LoadedWaveformPresentation?
    private var movedPlayhead = false

    func handle(
        _ event: SurfaceEvent, model: ReplicaModel, deck: DeckID, visibleSeconds: Double,
        width: Double, onZoom: (Double) -> Void
    ) {
        if ignoring {
            if event.remaining.isEmpty || event.phase == .cancelled { ignoring = false }
            return
        }
        if active, load != model.loadIdentity(deck) || wasEditing != model.editing.contains(deck)
            || wasFrozen != model.frozen.contains(deck)
        {
            if let stopped { model.clearStoppedStripePlayhead(deck, owner: stopped.owner) }
            reset()
            ignoring = !event.remaining.isEmpty && event.phase != .cancelled
            return
        }
        if event.phase == .cancelled {
            if active { restorePreview(model: model, deck: deck) }
            reset()
            return
        }
        guard let track = model.track(deck), track.analysis.frameCount > 0,
            event.points.allSatisfy({ $0.x.isFinite }), let first = event.points.first else {
            if active, event.phase == .ended && event.remaining.isEmpty {
                restorePreview(model: model, deck: deck)
                reset()
            }
            return
        }
        let frames = Double(track.analysis.frameCount)
        if !active {
            guard event.phase == .began else { return }
            active = true
            load = model.loadIdentity(deck)
            center = model.viewport[deck] ?? 0
            wasPreviewing = model.previewing.contains(deck)
            wasReleased = model.releasedStripePreviews.remove(deck) != nil
            wasEditing = model.editing.contains(deck)
            wasFrozen = model.frozen.contains(deck)
            if let generation = model.stoppedStripeGeneration(deck) { stopped = (UUID(), generation) }
            initialPresentation = model.loadedWaveformPresentations[deck]
            let halfWindow = max(10 / max(1, width), visibleSeconds / track.analysis.duration) / 2
            let offset = first.x - center / frames
            drag = Drag(contact: first.id, offset: abs(offset) <= halfWindow ? offset : 0)
            model.previewing.insert(deck)
        }
        if event.points.count > 2 {
            restorePreview(model: model, deck: deck)
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
            let frame = model.boundedFrame((point.x - drag.offset) * frames, deck: deck)
            model.loadedWaveformPresentations[deck] = nil
            model.viewport[deck] = frame
            if let stopped {
                movedPlayhead = movedPlayhead || abs(frame - center) >= 1
                if movedPlayhead {
                    model.stoppedStripePlayheads[deck] = .init(
                        owner: stopped.owner, generation: stopped.generation, frame: frame)
                }
            }
        }
        // A remaining pinch contact must not become a navigation drag.
        if pinch != nil, event.remaining.count < 2 {
            restorePreview(model: model, deck: deck)
            reset()
            ignoring = !event.remaining.isEmpty
        } else if event.phase == .ended && event.remaining.isEmpty {
            if let stopped {
                if movedPlayhead, let target = model.stoppedStripePlayheads[deck], target.owner == stopped.owner {
                    model.commitStoppedStripePlayhead(
                        deck, owner: stopped.owner, generation: stopped.generation, frame: target.frame)
                } else {
                    restorePreview(model: model, deck: deck)
                }
            } else if !wasEditing, !wasFrozen,
                StripePreviewRelease.detached(previouslyReleased: wasReleased,
                                              start: center, end: model.viewport[deck] ?? center)
            {
                model.releasedStripePreviews.insert(deck)
            } else if !wasEditing, !wasFrozen {
                restorePreview(model: model, deck: deck)
            }
            reset()
        }
    }

    private func restorePreview(model: ReplicaModel, deck: DeckID) {
        if let stopped {
            model.clearStoppedStripePlayhead(deck, owner: stopped.owner)
            if let initialPresentation { model.loadedWaveformPresentations[deck] = initialPresentation }
            model.viewport[deck] = center
            if !wasPreviewing { model.previewing.remove(deck) }
            if wasReleased { model.releasedStripePreviews.insert(deck) }
        } else if wasPreviewing || wasEditing || wasFrozen {
            model.viewport[deck] = center
            if !wasPreviewing { model.previewing.remove(deck) }
            if wasReleased { model.releasedStripePreviews.insert(deck) }
        } else {
            model.returnToPlayhead(deck: deck)
        }
    }

    private func reset() {
        active = false
        drag = nil
        pinch = nil
        stopped = nil
        initialPresentation = nil
        movedPlayhead = false
    }
}

enum StripePreviewRelease {
    static func detached(previouslyReleased: Bool, start: Double, end: Double) -> Bool {
        previouslyReleased || abs(end - start) >= 1
    }
}
