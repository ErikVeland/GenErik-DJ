import CoreGraphics
import Foundation

enum TouchSurfaceGeometryPolicy { case cancelOnResize, retainContactSpace }

struct TouchSurfaceViewport: Equatable {
    let size: CGSize
    let orientation: Int
    let interruption: UUID
}

struct TouchContactGeometry {
    let policy: TouchSurfaceGeometryPolicy
    private var frames: [Int: CGRect] = [:]
    private var originalFrame: CGRect?
    private var originalViewport: TouchSurfaceViewport?

    mutating func begin(id: Int, frame: CGRect, viewport: TouchSurfaceViewport) -> Bool {
        guard frame.width > 0, frame.height > 0,
            [frame.minX, frame.minY, frame.width, frame.height, viewport.size.width, viewport.size.height].allSatisfy(
                \.isFinite), viewport.size.width > 0, viewport.size.height > 0,
            originalViewport == nil || originalViewport == viewport
        else { return false }
        guard frames[id] == nil else { return false }
        if frames.isEmpty {
            originalFrame = frame
            originalViewport = viewport
        }
        frames[id] = frame
        return true
    }

    func point(id: Int, location: CGPoint, frame: CGRect) -> SurfacePoint? {
        guard let captured = frames[id], location.x.isFinite, location.y.isFinite else { return nil }
        let reference = policy == .retainContactSpace ? captured : frame
        guard reference.width > 0, reference.height > 0 else { return nil }
        return SurfacePoint(
            id: id, x: (location.x - reference.minX) / reference.width,
            y: (location.y - reference.minY) / reference.height)
    }

    func requiresCancellation(frame: CGRect, viewport: TouchSurfaceViewport) -> Bool {
        guard !frames.isEmpty else { return false }
        return viewport != originalViewport || (policy == .cancelOnResize && frame.size != originalFrame?.size)
    }

    mutating func end(ids: Set<Int>) {
        for id in ids { frames[id] = nil }
        if frames.isEmpty { cancel() }
    }

    mutating func cancel() {
        frames.removeAll()
        originalFrame = nil
        originalViewport = nil
    }
}

/// A held gesture keeps its musical scale until its final release or cancellation.
struct TouchGestureValue {
    private var held: Double?
    mutating func value(for event: SurfaceEvent, current: Double) -> Double {
        if held == nil, current.isFinite { held = current }
        let result = held ?? 0
        if event.phase == .cancelled || (event.phase == .ended && event.remaining.isEmpty) { held = nil }
        return result
    }
}

struct SurfacePoint: Equatable {
    let id: Int
    var x: Double
    var y: Double
}
struct SurfaceEvent {
    enum Phase { case began, moved, ended, cancelled }
    let phase: Phase
    /// Includes ending contacts for the final event, allowing release-position inspection.
    let points: [SurfacePoint]
    let ending: Set<Int>
    var remaining: [SurfacePoint] { points.filter { !ending.contains($0.id) } }
    static func owned(phase: Phase, points: [SurfacePoint], changed: Set<Int>, ending: Set<Int> = []) -> SurfaceEvent? {
        guard !points.isEmpty, !changed.isDisjoint(with: points.lazy.map(\.id)) else { return nil }
        return .init(phase: phase, points: points, ending: ending.intersection(points.lazy.map(\.id)))
    }
}
