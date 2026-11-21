import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func extraGridContactCannotCommitAnUnrelatedPhaseShift() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
        .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    await model.importFiles([fixture])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    let grid = try #require(model.grid(.a))
    model.editing.insert(.a)
    model.viewport[.a] = 96000
    let session = WaveformGestureSession()
    let first = SurfacePoint(id: 1, x: 0.25, y: 0.5)
    let moved = SurfacePoint(id: 1, x: 0.3, y: 0.5)
    let second = SurfacePoint(id: 2, x: 0.75, y: 0.5)
    session.handle(.init(phase: .began, points: [first], ending: []), model: model, deck: .a, span: 96000)
    session.handle(.init(phase: .moved, points: [moved], ending: []), model: model, deck: .a, span: 96000)
    #expect(model.gridDraft[.a] != nil)
    session.handle(.init(phase: .began, points: [moved, second], ending: []), model: model, deck: .a, span: 96000)
    session.handle(.init(phase: .moved, points: [moved, second], ending: []), model: model, deck: .a, span: 96000)
    session.handle(.init(phase: .ended, points: [moved, second], ending: [1, 2]), model: model, deck: .a, span: 96000)
    await model.flushWrites()
    #expect(model.gridDraft[.a] == nil)
    #expect(model.grid(.a) == grid)
    #expect(model.viewport[.a] == 96000)
    model.editing.remove(.a)
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 100)
    model.refreshPlayback()
    let playing = try #require(model.playbackSnapshot?.a)
    model.previewing.insert(.a)
    model.viewport[.a] = 150000
    model.returnToPlayhead(deck: .a)
    #expect(!model.previewing.contains(.a))
    #expect(model.viewport[.a] == playing.sourceFrame)
    #expect(model.playbackSnapshot?.a.sourceFrame == playing.sourceFrame)
    #expect(model.playbackSnapshot?.a.phase == playing.phase)
    model.frozen.insert(.a)
    model.viewport[.a] = 0
    model.performance.slicerQuantize = false
    let slices = WaveformGestureSession()
    let span = track.analysis.sampleRate * 8
    let blank = SurfacePoint(id: 2, x: 0.05, y: 0.5)
    let valid = SurfacePoint(id: 1, x: 0.75, y: 0.5)
    slices.handle(.init(phase: .began, points: [blank], ending: []), model: model, deck: .a, span: span)
    slices.handle(.init(phase: .ended, points: [blank], ending: [2]), model: model, deck: .a, span: span)
    #expect(model.playbackSnapshot?.a.sourceFrame == playing.sourceFrame)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    slices.handle(.init(phase: .began, points: [valid], ending: []), model: model, deck: .a, span: span)
    let heldFrame = model.playbackSnapshot?.a.sourceFrame
    #expect(model.playbackSnapshot?.a.touchActive == true)
    slices.handle(.init(phase: .began, points: [valid, blank], ending: []), model: model, deck: .a, span: span)
    #expect(model.playbackSnapshot?.a.sourceFrame == heldFrame)
    slices.handle(.init(phase: .ended, points: [valid, blank], ending: [1]), model: model, deck: .a, span: span)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    slices.handle(.init(phase: .ended, points: [blank], ending: [2]), model: model, deck: .a, span: span)
    #expect(model.playbackSnapshot?.a.sourceFrame == heldFrame)
    await model.flushWaveforms()
    await model.finishForShutdown()
}

@Test @MainActor func gridPinchChangesOnlyScaleAndRetainsContactOwnership() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
        .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    await model.importFiles([fixture])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 128)
    model.refreshPlayback()
    let original = try #require(model.playback.core.snapshot())
    let grid = try #require(model.grid(.a))
    model.editing.insert(.a)
    model.viewport[.a] = 96000
    let session = WaveformGestureSession()
    var span = 96000.0
    var zooms: [Double] = []
    func point(_ id: Int, _ x: Double) -> SurfacePoint { .init(id: id, x: x, y: 0.5) }
    func send(_ phase: SurfaceEvent.Phase, _ points: [SurfacePoint], _ ending: Set<Int> = []) {
        session.handle(.init(phase: phase, points: points, ending: ending), model: model, deck: .a, span: span) {
            span = $0
            zooms.append($0)
        }
    }
    send(.began, [point(1, 0.25)])
    send(.moved, [point(1, 0.3)])
    #expect(model.gridDraft[.a] != nil)
    send(.began, [point(1, 0.3), point(2, 0.75)])
    send(.moved, [point(2, 0.75), point(1, 0.3)])
    #expect(zooms.isEmpty && model.gridDraft[.a] == nil && model.viewport[.a] == 96000)
    send(.moved, [point(2, 0.9), point(1, 0.1)])
    #expect(abs(span - 54000) < 0.000001)
    send(.moved, [point(1, 0.3875), point(2, 0.6125)])
    // Re-rendered spans do not replace the original pinch baseline.
    #expect(abs(span - 192000) < 0.000001)
    let count = zooms.count
    send(.ended, [point(1, 0.3875), point(2, 0.6125)], [2])
    send(.moved, [point(1, 0.9)])
    send(.ended, [point(1, 0.9)], [1])
    #expect(zooms.count == count && model.gridDraft[.a] == nil)
    // A third contact ends zoom ownership until every contact has lifted.
    send(.began, [point(3, 0.25), point(4, 0.75)])
    send(.began, [point(3, 0.25), point(4, 0.75), point(5, 0.5)])
    send(.ended, [point(3, 0.25), point(4, 0.75), point(5, 0.5)], [5])
    send(.moved, [point(3, 0.1), point(4, 0.9)])
    send(.ended, [point(3, 0.1), point(4, 0.9)], [3, 4])
    #expect(zooms.count == count)
    send(.began, [point(6, 0.25), point(7, 0.75)])
    send(.moved, [point(6, 0.1), point(7, 0.9)])
    let cancelledSpan = span
    send(.cancelled, [point(6, 0.1), point(7, 0.9)], [6, 7])
    #expect(span == cancelledSpan && model.gridDraft[.a] == nil)
    send(.began, [point(8, 0.25), point(9, 0.75)])
    let beforeModeChange = zooms.count
    model.editing.remove(.a)
    send(.moved, [point(8, 0.1), point(9, 0.9)])
    send(.ended, [point(8, 0.1), point(9, 0.9)], [8, 9])
    #expect(zooms.count == beforeModeChange)
    await model.flushWrites()
    #expect(model.grid(.a) == grid && model.gridDraft[.a] == nil)
    #expect(model.viewport[.a] == 96000)
    #expect(model.playback.core.snapshot() == original)
    await model.flushWaveforms()
    await model.finishForShutdown()
}

@Test func gridZoomUsesTheExistingStripeScaleBounds() {
    #expect(WaveformZoom.seconds(frameSpan: 1, sampleRate: 48000, duration: 240) == 1)
    #expect(WaveformZoom.seconds(frameSpan: 48000 * 999, sampleRate: 48000, duration: 240) == 240)
    #expect(WaveformZoom.seconds(frameSpan: 48000 * 8, sampleRate: 48000, duration: 240) == 8)
    #expect(WaveformZoom.seconds(frameSpan: 1, sampleRate: 48000, duration: 0.5) == 0.5)
}

@Test @MainActor func deckZoomResetsOnSameTrackReloadAndKeepsTheOtherDecksZoom() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let fixtures = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles(["clock-a-120.wav", "clock-b-128.wav"].map { fixtures.appendingPathComponent($0) })
    let tracks = model.library.tracks.sorted { ($0.bpm ?? 0) < ($1.bpm ?? 0) }
    let a = try #require(tracks.first)
    let b = try #require(tracks.last)
    try #require(a.bpm != b.bpm)
    model.load(trackID: a.id, deck: .a)
    model.load(trackID: b.id, deck: .b)
    await model.flushWrites()

    #expect(model.waveformZoomSeconds(deck: .a) == 2.5)
    #expect(model.waveformZoomSeconds(deck: .b) == 2.5)
    let original = try #require(model.loadIdentity(.a))
    model.setWaveformZoomSeconds(4, deck: .a, loadID: original)
    model.setWaveformZoomSeconds(6, deck: .b, loadID: model.loadIdentity(.b))
    #expect(model.waveformZoomSeconds(deck: .a) == 4)

    model.load(trackID: a.id, deck: .a)
    #expect(model.waveformZoomSeconds(deck: .a) == 2.5)
    await model.flushWrites()
    #expect(model.loaded[.a] == a.id)
    #expect(model.loadIdentity(.a) != original)
    model.setWaveformZoomSeconds(4, deck: .a, loadID: original)
    #expect(model.waveformZoomSeconds(deck: .a) == 2.5)
    #expect(model.waveformZoomSeconds(deck: .b) == 6)
    await model.finishForShutdown()
}

@Test @MainActor func beatFixCentersDownbeatWithoutSeekingAndRetainsInspection() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    model.jump(12_000, deck: .a, quantized: false)
    let before = try #require(model.playbackSnapshot?.a.sourceFrame)
    let timing = try #require(model.timing(.a))
    model.pressPlay(deck: .a, vinylStop: false)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    let playing = try #require(model.playbackSnapshot?.a)
    #expect(playing.phase == .playing)
    let target = try #require(timing.nearestDownbeatFrame(
        to: playing.sourceFrame, within: 0..<Double(track.analysis.frameCount)))
    model.toggleGridEditing(deck: .a)
    #expect(model.viewport[.a] == target)
    #expect(model.playbackSnapshot?.a.sourceFrame == playing.sourceFrame)
    for _ in 0..<3 {
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
        #expect(model.viewport[.a] == target)
    }
    #expect(model.playbackSnapshot?.a.sourceFrame != before)
    model.viewport[.a] = 9876
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    #expect(model.viewport[.a] == 9876)
    let beforeDone = try #require(model.playbackSnapshot?.a)
    #expect(beforeDone.phase == .playing)
    model.toggleGridEditing(deck: .a)
    #expect(model.playbackSnapshot?.a.phase == .playing)
    #expect(model.playbackSnapshot?.a.sourceFrame == beforeDone.sourceFrame)
    #expect(model.viewport[.a] == beforeDone.sourceFrame)
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.phase == .playing)
    #expect(model.viewport[.a] == model.playbackSnapshot?.a.sourceFrame)
    await model.finishForShutdown()
}

@Test func gridInspectionPinsCurrentViewportWhenNoBeatOneCanBeFound() throws {
    let noGrid = GridInspectionViewport.start(current: 5000, playhead: 6000, timing: nil, frameCount: 99_000)
    #expect(noGrid.previous == 5000 && noGrid.center == 5000)
    let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000, downbeatOffset: 1)
    let short = GridInspectionViewport.start(
        current: .nan, playhead: 4000, timing: BeatTiming(fixed: fixed), frameCount: 20_000)
    #expect(short.previous == 4000 && short.center == 4000)
    let missing = GridInspectionViewport.start(current: nil, playhead: .infinity, timing: nil, frameCount: 0)
    #expect(missing.previous == 0 && missing.center == 0)
}
