import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func previewBeatTapIgnoresFingerJitterAndCommitsOnGrid() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    model.previewing.insert(.a)
    model.viewport[.a] = track.analysis.sampleRate * 6
    let session = WaveformGestureSession()
    let first = SurfacePoint(id: 1, x: 0.5, y: 0.5)
    let jitter = SurfacePoint(id: 1, x: 0.501, y: 0.5)
    let span = track.analysis.sampleRate * 2
    session.handle(.init(phase: .began, points: [first], ending: []), model: model, deck: .a, span: span)
    session.handle(.init(phase: .moved, points: [jitter], ending: []), model: model, deck: .a, span: span)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.sourceFrame == 0)
    session.handle(.init(phase: .ended, points: [jitter], ending: [1]), model: model, deck: .a, span: span)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.sourceFrame == track.analysis.sampleRate * 6)
    #expect(model.playbackSnapshot?.a.synced == true)
    #expect(!model.previewing.contains(.a))
    await model.finishForShutdown()
}

@Test @MainActor func stripeDragRetainsGrabOffsetAndNeverMovesAudio() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    let frames = Double(track.analysis.frameCount)
    model.viewport[.a] = frames * 0.5
    model.previewing.insert(.a)
    let before = model.playback.core.snapshot()
    let session = StripeGestureSession()
    func send(_ phase: SurfaceEvent.Phase, _ x: Double, ending: Bool = false) {
        session.handle(
            .init(phase: phase, points: [.init(id: 1, x: x, y: 0.5)], ending: ending ? [1] : []),
            model: model, deck: .a, visibleSeconds: track.analysis.duration * 0.2, width: 400) { _ in }
    }
    send(.began, 0.58)
    #expect(model.viewport[.a] == frames * 0.5)
    send(.moved, 0.68)
    #expect(abs(try #require(model.viewport[.a]) - frames * 0.6) < 0.001)
    send(.ended, 0.68, ending: true)
    model.refreshPlayback()
    #expect(model.previewing.contains(.a))
    #expect(model.playback.core.snapshot() == before)
    send(.began, 1.5)
    send(.ended, 1.5, ending: true)
    #expect(model.viewport[.a] == frames - 1)
    #expect(model.playback.core.snapshot() == before)
    model.returnToPlayhead(deck: .a)
    #expect(model.viewport[.a] == 0 && !model.previewing.contains(.a))
    await model.finishForShutdown()
}

@Test @MainActor func stripePinchKeepsContactOwnershipAndCancellationRestoresFollowing() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    let session = StripeGestureSession()
    var seconds = 4.0
    func point(_ id: Int, _ x: Double) -> SurfacePoint { .init(id: id, x: x, y: 0.5) }
    func send(_ phase: SurfaceEvent.Phase, _ points: [SurfacePoint], _ ending: Set<Int> = []) {
        session.handle(.init(phase: phase, points: points, ending: ending), model: model, deck: .a,
                       visibleSeconds: seconds, width: 400) { seconds = $0 }
    }
    send(.began, [point(1, 0.25), point(2, 0.75)])
    send(.moved, [point(2, 1), point(1, 0)])
    #expect(seconds == 2)
    send(.moved, [point(1, 0.25), point(2, 0.75)])
    #expect(seconds == 4)
    send(.ended, [point(1, 0.25), point(2, 0.75)], [2])
    send(.moved, [point(1, 0.9)])
    send(.ended, [point(1, 0.9)], [1])
    #expect(model.viewport[.a] == 0)
    model.returnToPlayhead(deck: .a)
    send(.began, [point(3, 0.5)])
    send(.moved, [point(3, 0.6)])
    #expect(try #require(model.viewport[.a]) > 0)
    send(.cancelled, [point(3, 0.6)], [3])
    #expect(model.viewport[.a] == 0 && !model.previewing.contains(.a))
    #expect(model.playbackSnapshot?.a.sourceFrame == 0)
    await model.finishForShutdown()
}

@Test @MainActor func stripeHeldContactCannotMoveAReloadedTrack() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    let session = StripeGestureSession()
    let point = SurfacePoint(id: 1, x: 0.75, y: 0.5)
    session.handle(.init(phase: .began, points: [point], ending: []), model: model, deck: .a,
                   visibleSeconds: 2, width: 400) { _ in }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a,
                   visibleSeconds: 2, width: 400) { _ in }
    #expect(model.viewport[.a] == 0 && !model.previewing.contains(.a))
    await model.finishForShutdown()
}
