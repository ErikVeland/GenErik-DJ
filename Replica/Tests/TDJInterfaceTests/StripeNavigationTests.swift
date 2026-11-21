import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func stoppedWaveformTapIgnoresFingerJitterAndCommitsAtRelease() async throws {
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
    #expect(abs(try #require(model.playbackSnapshot?.a.sourceFrame) - (track.analysis.sampleRate * 6 + 0.001 * span)) < 0.0001)
    #expect(model.playbackSnapshot?.a.synced == true)
    #expect(!model.previewing.contains(.a))
    await model.finishForShutdown()
}

@Test @MainActor func stripeDragRetainsGrabOffsetAndNeverMovesAudio() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    try model.playback.play(.a)
    model.refreshPlayback()
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
    #expect(!model.canReturnFromStripePreview(.a))
    #expect(abs(try #require(model.viewport[.a]) - frames * 0.6) < 0.001)
    send(.ended, 0.68, ending: true)
    model.refreshPlayback()
    #expect(model.canReturnFromStripePreview(.a))
    #expect(model.previewing.contains(.a))
    #expect(model.playback.core.snapshot() == before)
    send(.began, 1.5)
    send(.ended, 1.5, ending: true)
    #expect(model.viewport[.a] == frames - 1)
    #expect(model.playback.core.snapshot() == before)
    model.returnToPlayhead(deck: .a)
    #expect(model.viewport[.a] == 0 && !model.previewing.contains(.a))
    #expect(!model.canReturnFromStripePreview(.a))
    await model.finishForShutdown()
}

@Test @MainActor func stripePinchKeepsContactOwnershipAndCancellationRestoresFollowing() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    let initial = model.viewport[.a]
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
    #expect(model.viewport[.a] == initial)
    send(.began, [point(3, 0.5)])
    send(.moved, [point(3, 0.6)])
    #expect(try #require(model.viewport[.a]) > 0)
    send(.cancelled, [point(3, 0.6)], [3])
    #expect(model.viewport[.a] == initial && !model.previewing.contains(.a))
    #expect(!model.canReturnFromStripePreview(.a))
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
    let reloadedCenter = model.viewport[.a]
    session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a,
                   visibleSeconds: 2, width: 400) { _ in }
    #expect(model.viewport[.a] == reloadedCenter && !model.previewing.contains(.a))
    #expect(!model.canReturnFromStripePreview(.a))
    #expect(model.playbackSnapshot?.a.sourceFrame == 0)
    await model.finishForShutdown()
}

@Test @MainActor func stripeReturnWhilePlayingChangesOnlyDisplayedFrame() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    try model.playback.play(.a)
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    let session = StripeGestureSession()
    let point = SurfacePoint(id: 1, x: 0.9, y: 0.5)
    session.handle(.init(phase: .began, points: [point], ending: []), model: model, deck: .a,
                   visibleSeconds: 2, width: 400) { _ in }
    #expect(!model.canReturnFromStripePreview(.a))
    session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a,
                   visibleSeconds: 2, width: 400) { _ in }
    #expect(model.canReturnFromStripePreview(.a))
    let preview = model.viewport[.a]
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    #expect(model.viewport[.a] == preview)
    let before = try #require(model.playback.core.snapshot())
    #expect(before.a.phase == .playing)
    model.returnToPlayhead(deck: .a)
    #expect(!model.canReturnFromStripePreview(.a))
    #expect(model.viewport[.a] == before.a.sourceFrame)
    #expect(model.playback.core.snapshot() == before)
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    #expect(model.viewport[.a] == model.playbackSnapshot?.a.sourceFrame)
    #expect(model.viewport[.a] != before.a.sourceFrame)
    await model.finishForShutdown()
}

@Test func soundButtonUsesRECOnlyWhileCapturing() {
    #expect(RecordingOutputIndicator(active: false, starting: false, finishing: false) == .idle)
    #expect(RecordingOutputIndicator(active: false, starting: true, finishing: false) == .starting)
    #expect(RecordingOutputIndicator(active: true, starting: false, finishing: false) == .recording)
    #expect(RecordingOutputIndicator(active: true, starting: false, finishing: true) == .finishing)
}

@Test(arguments: [false, true]) @MainActor
func stoppedStripeCommitsCursorOnceWithoutStartingOrChangingPhase(streaming: Bool) async throws {
    let (model, root, track) = try await loadPlayheadFixture(streaming: streaming)
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    let original = try #require(model.playbackSnapshot?.a)
    let gesture = StripeGestureSession()
    let target = Double(track.analysis.frameCount) * 0.95
    let point = SurfacePoint(id: 1, x: 0.95, y: 0.5)
    gesture.handle(.init(phase: .began, points: [point], ending: []), model: model, deck: .a,
                   visibleSeconds: 1, width: 400) { _ in }
    #expect(model.displayedStripePlayhead(.a) == target)
    #expect(model.playback.core.snapshot()?.a.sourceFrame == original.sourceFrame)
    gesture.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a,
                   visibleSeconds: 1, width: 400) { _ in }
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    let parked = try #require(model.playbackSnapshot?.a)
    #expect(abs(parked.sourceFrame - target) < 0.01)
    #expect(parked.phase == original.phase)
    #expect(!model.canReturnFromStripePreview(.a))
    #expect(model.displayedStripePlayhead(.a) == nil)
    model.pressPlay(deck: .a)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    let started = try #require(model.playbackSnapshot?.a)
    #expect(started.phase == .playing)
    #expect(started.sourceFrame == parked.sourceFrame)
    _ = model.playback.core.renderOffline(frames: 128)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.lastStartOutputFrame == started.lastStartOutputFrame)
    await model.finishForShutdown()
}

@Test @MainActor func playDuringColdStoppedSeekStartsAtRequestedFrame() async throws {
    let (model, root, track) = try await loadPlayheadFixture(streaming: true)
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .b)
    await model.playbackLoads?.value
    let original = try #require(model.playbackSnapshot?[.b])
    let target = Double(track.analysis.frameCount) * 0.96
    var settled = false
    try model.playback.seekStoppedPreview(to: target, deck: .b, generation: original.generation) {
        settled = true
    }
    try model.playback.play(.b)
    #expect(model.playback.playAfterStoppedPreview.contains(.b))
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    let started = try #require(model.playbackSnapshot?[.b])
    #expect(settled)
    #expect(started.phase == .playing)
    #expect(abs(started.sourceFrame - target) < 0.01)
    #expect(!model.playback.playAfterStoppedPreview.contains(.b))
    await model.finishForShutdown()
}
