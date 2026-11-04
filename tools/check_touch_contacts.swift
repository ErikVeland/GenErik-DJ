import Foundation
import CoreGraphics

@main
enum TouchContactChecks {
    @MainActor static func main() {
        var checks = 0
        var failures = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: \(message)") }
        }
        let epoch = UUID()
        let viewport = TouchSurfaceViewport(size: CGSize(width: 1112, height: 834), orientation: 3, interruption: epoch)
        let original = CGRect(x: 100, y: 120, width: 200, height: 240)
        let resized = CGRect(x: 160, y: 50, width: 90, height: 40)
        var geometry = TouchContactGeometry(policy: .retainContactSpace)
        expect(geometry.begin(id: 1, frame: original, viewport: viewport), "first contact owns the surface")
        let windowPoint = CGPoint(x: 200, y: 240)
        let first = geometry.point(id: 1, location: windowPoint, frame: original)!
        expect(first.x == 0.5 && first.y == 0.5, "initial contact mapping")
        expect(!geometry.requiresCancellation(frame: resized, viewport: viewport), "panel resize retains held contact")
        let stationary = geometry.point(id: 1, location: windowPoint, frame: resized)!
        expect(stationary == first, "stationary finger unchanged after size and origin change")
        expect(!geometry.requiresCancellation(frame: .zero, viewport: viewport), "fully collapsed surface retains held contact")
        expect(geometry.point(id: 1, location: windowPoint, frame: .zero) == first, "collapsed surface keeps original musical value")
        expect(!geometry.begin(id: 1, frame: resized, viewport: viewport) && geometry.point(id: 1, location: windowPoint, frame: resized) == first,
            "duplicate begin cannot replace held finger geometry")
        let moved = geometry.point(id: 1, location: CGPoint(x: 220, y: 264), frame: resized)!
        expect(abs(moved.x - 0.6) < 0.000001 && abs(moved.y - 0.6) < 0.000001, "movement continues at original scale")
        expect(geometry.point(id: 9, location: windowPoint, frame: resized) == nil, "unowned contact cannot control surface")
        expect(geometry.begin(id: 2, frame: resized, viewport: viewport), "second contact joins held gesture")
        expect(geometry.point(id: 2, location: CGPoint(x: 205, y: 70), frame: resized)?.x == 0.5, "new finger captures current geometry")
        geometry.end(ids: [1])
        expect(geometry.point(id: 1, location: windowPoint, frame: resized) == nil, "released contact cannot return")
        expect(geometry.point(id: 2, location: CGPoint(x: 205, y: 70), frame: original)?.y == 0.5, "remaining contact retains its own mapping")
        geometry.end(ids: [2])
        expect(geometry.begin(id: 3, frame: resized, viewport: viewport), "new gesture uses new geometry")
        let next = geometry.point(id: 3, location: CGPoint(x: 205, y: 70), frame: resized)!
        expect(next.x == 0.5 && next.y == 0.5, "new gesture latches resized frame")
        expect(geometry.requiresCancellation(frame: resized, viewport: .init(size: CGSize(width: 834, height: 1112), orientation: 1, interruption: epoch)), "rotation cancels explicitly")
        expect(geometry.requiresCancellation(frame: resized, viewport: .init(size: viewport.size, orientation: 3, interruption: UUID())), "interruption cancels explicitly")
        geometry.cancel()
        expect(geometry.point(id: 3, location: windowPoint, frame: resized) == nil, "cancelled contact rejects stale events")
        expect(!geometry.begin(id: 4, frame: .zero, viewport: viewport), "zero-size surface rejects new contacts")

        var legacy = TouchContactGeometry(policy: .cancelOnResize)
        _ = legacy.begin(id: 1, frame: original, viewport: viewport)
        expect(legacy.requiresCancellation(frame: resized, viewport: viewport), "unmigrated surfaces retain cancellation policy")
        var deckA = TouchContactGeometry(policy: .retainContactSpace)
        var deckB = TouchContactGeometry(policy: .retainContactSpace)
        _ = deckA.begin(id: 1, frame: original, viewport: viewport)
        _ = deckB.begin(id: 1, frame: resized, viewport: viewport)
        deckA.cancel()
        expect(deckB.point(id: 1, location: CGPoint(x: 205, y: 70), frame: original)?.x == 0.5, "one deck cannot cancel another")

        var mapping = TouchContactGeometry(policy: .retainContactSpace)
        _ = mapping.begin(id: 1, frame: original, viewport: viewport)
        let event = SurfaceEvent(phase: .began, points: [mapping.point(id: 1, location: CGPoint(x: 150, y: 180), frame: original)!], ending: [])
        let later = SurfaceEvent(phase: .moved, points: [mapping.point(id: 1, location: CGPoint(x: 150, y: 180), frame: resized)!], ending: [])
        let fader = FaderGestureSession()
        var before = -1.0, after = -1.0
        fader.handle(event, value: 1, range: 0...2, reset: 1, axis: .vertical, insetFraction: 6 / 240) { before = $0 }
        fader.handle(later, value: before, range: 0...2, reset: 1, axis: .vertical, insetFraction: 6 / 40) { after = $0 }
        expect(abs(before - after) < 0.000001, "EQ value does not jump when its length changes")
        _ = mapping.begin(id: 2, frame: resized, viewport: viewport)
        let second = mapping.point(id: 2, location: CGPoint(x: 205, y: 60), frame: resized)!
        var temporary = -1.0, restored = -1.0
        fader.handle(.init(phase: .began, points: event.points + [second], ending: []), value: before, range: 0...2, reset: 1, axis: .vertical, insetFraction: 6 / 40) { temporary = $0 }
        expect(abs(temporary - 1.7142857142857142) < 0.000001, "new EQ finger uses the resized control inset")
        fader.handle(.init(phase: .ended, points: event.points + [second], ending: [2]), value: temporary, range: 0...2, reset: 1, axis: .vertical, insetFraction: 6 / 40) { restored = $0 }
        expect(abs(before - restored) < 0.000001, "EQ temporary second finger restores original target")
        var cancelled = -1.0
        fader.handle(.init(phase: .cancelled, points: [], ending: []), value: restored, range: 0...2, reset: 1, axis: .vertical) { cancelled = $0 }
        expect(cancelled == -1, "single-finger cancellation does not invent EQ reset")

        let filter = FilterPadContactState()
        expect(filter.update(event), "filter initial contact accepts X")
        expect(!filter.update(later), "stationary filter retains hardware X after resize")
        expect(event.points[0].y == later.points[0].y, "filter resonance unchanged after resize")
        var effect = EffectPadGestureSession()
        expect(effect.handle(event, selectedSlot: 1)?.slot == 1, "FX selects original slot")
        let effectUpdate = effect.handle(later, selectedSlot: 2)
        expect(effectUpdate?.slot == 1 && effectUpdate?.updateX == false, "FX holds slot and axes after resize")
        expect(effect.handle(.init(phase: .ended, points: later.points, ending: [1]), selectedSlot: 2)?.slot == 1 && effect.activeSlot == nil, "FX release ends original gesture")

        var span = TouchGestureValue()
        expect(span.value(for: event, current: 96000) == 96000, "waveform captures source span")
        expect(span.value(for: later, current: 192000) == 96000, "held waveform retains span after redraw")
        expect(span.value(for: .init(phase: .ended, points: event.points, ending: [1]), current: 192000) == 96000, "release uses original waveform span")
        expect(span.value(for: event, current: 192000) == 192000, "new waveform gesture uses current span")
        _ = span.value(for: .init(phase: .cancelled, points: event.points, ending: [1]), current: 1)
        expect(span.value(for: event, current: 48000) == 48000, "cancel clears waveform geometry snapshot")
        print("\(checks) held-contact checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
