import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@MainActor private func superSlicerFixture() async throws -> (ReplicaModel, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
        .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    await model.importFiles([fixture])
    let track = try #require(model.library.tracks.first)
    for deck in DeckID.allCases { model.load(trackID: track.id, deck: deck) }
    await model.flushWrites()
    model.viewport[.a] = 64000
    model.viewport[.b] = 64000
    model.performance.slicerQuantize = false
    return (model, root)
}

@Test func superSlicerPrimaryFamilyOrderAndVerticalLabels() {
    #expect(SuperSlicerFamily.allCases == [.loopStutter, .turntablism, .pitch])
    #expect((0..<3).map { SuperSlicerFamily.turntablism.label(row: $0) } == ["Brake", "Scratch", "Reverse"])
    #expect((0..<3).map { SuperSlicerFamily.pitch.label(row: $0) } == ["Pitch Up", "Slice", "Pitch Down"])
    #expect((0..<3).map { SuperSlicerFamily.loopStutter.label(row: $0) } == ["Slice", "½ Slice", "¼ Slice"])
    #expect(SuperSlicerFamily.turntablism.action(at: 1.0 / 3) == .scratch)
    #expect(SuperSlicerFamily.turntablism.action(at: 2.0 / 3) == .reverse)
    #expect(SuperSlicerFamily.pitch.action(at: 1.0 / 3) == .slice)
    #expect(SuperSlicerFamily.pitch.action(at: 2.0 / 3) == .pitchDown)
}

@Test @MainActor func superSlicerRegionsDriveCompoundActionsAndRelease() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let rows: [(SuperSlicerFamily, Double, Double, Double, Double)] = [
        (.turntablism, 0.1, 2.0 / 3, 56000, 64000), (.turntablism, 0.5, 0, 57600, 0),
        (.turntablism, 0.9, -1, 56000, 64000), (.pitch, 0.1, pow(2, 0.8), 56000, 64000), (.pitch, 0.5, 1, 56000, 64000),
        (.pitch, 0.9, pow(2, -0.8), 56000, 64000), (.loopStutter, 0.1, 1, 56000, 64000),
        (.loopStutter, 0.5, 1, 56000, 60000), (.loopStutter, 0.9, 1, 56000, 58000),
    ]
    for (family, y, rate, frame, end) in rows {
        model.selectSuperSlicerFamily(family, deck: .a)
        let session = WaveformGestureSession()
        let point = SurfacePoint(id: 1, x: 0.4, y: y)
        session.handle(.init(phase: .began, points: [point], ending: []), model: model, deck: .a, span: 64000)
        let active = try #require(model.playbackSnapshot?.a)
        #expect(active.touchActive)
        #expect(abs(active.performanceRate - rate) < 0.000001)
        #expect(active.sourceFrame == frame)
        #expect(active.touchEnd == end)
        session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a, span: 64000)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        #expect(model.playbackSnapshot?.a.phase == .paused)
    }
    await model.finishForShutdown()
}

@Test @MainActor func superSlicerScratchFollowsMovementWithoutRestartingTheCursor() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.turntablism, deck: .a)
    let other = try #require(model.playbackSnapshot?.b)
    let session = WaveformGestureSession()
    func send(_ phase: SurfaceEvent.Phase, _ x: Double) {
        let point = SurfacePoint(id: 1, x: x, y: 0.5)
        session.handle(
            .init(phase: phase, points: [point], ending: phase == .ended ? [1] : []), model: model, deck: .a,
            span: 64000)
    }
    send(.began, 0.4)
    #expect(model.playbackSnapshot?.a.performanceRate == 0)
    try await Task.sleep(for: .milliseconds(20))
    send(.moved, 0.400001)
    let slow = try #require(model.playbackSnapshot?.a.performanceRate)
    #expect(slow > 0 && slow < 0.01)
    send(.moved, 0.6)
    #expect(model.playbackSnapshot?.a.performanceRate == 4)
    _ = model.playback.core.renderOffline(frames: 256)
    model.refreshPlayback()
    let forward = try #require(model.playbackSnapshot?.a.sourceFrame)
    send(.moved, 0.3)
    #expect(model.playbackSnapshot?.a.performanceRate == -4)
    #expect(model.playbackSnapshot?.a.sourceFrame == forward)
    _ = model.playback.core.renderOffline(frames: 256)
    model.refreshPlayback()
    let backward = try #require(model.playbackSnapshot?.a.sourceFrame)
    #expect(backward < forward)
    send(.moved, 0.3)
    #expect(model.playbackSnapshot?.a.performanceRate == 0)
    _ = model.playback.core.renderOffline(frames: 256)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.sourceFrame == backward)
    #expect(model.playbackSnapshot?.b == other)
    send(.ended, 0.3)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.performanceRate == 1)
    #expect(model.playbackSnapshot?.a.phase == .paused)
    await model.finishForShutdown()
}

@Test @MainActor func superSlicerScratchContactHandoverStartsAtRest() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.turntablism, deck: .a)
    let session = WaveformGestureSession()
    let first = SurfacePoint(id: 1, x: 0.4, y: 0.5)
    let moved = SurfacePoint(id: 1, x: 0.5, y: 0.5)
    let second = SurfacePoint(id: 2, x: 0.7, y: 0.5)
    session.handle(.init(phase: .began, points: [first], ending: []), model: model, deck: .a, span: 64000)
    session.handle(.init(phase: .moved, points: [moved], ending: []), model: model, deck: .a, span: 64000)
    #expect(try #require(model.playbackSnapshot?.a.performanceRate) > 0)
    session.handle(.init(phase: .began, points: [moved, second], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.performanceRate == 0)
    #expect(model.playbackSnapshot?.a.sourceFrame == 76800)
    session.handle(.init(phase: .ended, points: [moved, second], ending: [2]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.performanceRate == 0)
    #expect(model.playbackSnapshot?.a.sourceFrame == 64000)
    let reverse = SurfacePoint(id: 1, x: 0.5, y: 0.9)
    session.handle(.init(phase: .moved, points: [reverse], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.performanceRate == -1)
    session.handle(.init(phase: .moved, points: [moved], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.performanceRate == 0)
    session.handle(.init(phase: .cancelled, points: [moved], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.performanceRate == 1)
    await model.finishForShutdown()
}

@Test @MainActor func superSlicerBrakeReachesAndHoldsAStopInsideItsRegion() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.turntablism, deck: .a)
    let session = WaveformGestureSession()
    for (index, y) in [0.0, 0.15, 0.3, 0.32].enumerated() {
        let point = SurfacePoint(id: 1, x: 0.4, y: y)
        session.handle(
            .init(phase: index == 0 ? .began : .moved, points: [point], ending: []), model: model, deck: .a, span: 64000
        )
        if index == 0 { #expect(model.playbackSnapshot?.a.performanceRate == 1) }
        if index == 1 { #expect(model.playbackSnapshot?.a.performanceRate == 0.5) }
        if index >= 2 {
            #expect(model.playbackSnapshot?.a.performanceRate == 0)
            let position = try #require(model.playbackSnapshot?.a.sourceFrame)
            _ = model.playback.core.renderOffline(frames: 512)
            model.refreshPlayback()
            #expect(model.playbackSnapshot?.a.sourceFrame == position)
        }
    }
    let point = SurfacePoint(id: 1, x: 0.4, y: 0.32)
    session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.performanceRate == 1)
    await model.finishForShutdown()
}

@Test @MainActor func superSlicerSameSliceActionTransitionAndSurvivingContact() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.pitch, deck: .a)
    let session = WaveformGestureSession()
    let up = SurfacePoint(id: 1, x: 0.4, y: 0.1)
    let slice = SurfacePoint(id: 1, x: 0.4, y: 0.5)
    session.handle(.init(phase: .began, points: [up], ending: []), model: model, deck: .a, span: 64000)
    _ = model.playback.core.renderOffline(frames: 64)
    model.refreshPlayback()
    let position = try #require(model.playbackSnapshot?.a.sourceFrame)
    session.handle(.init(phase: .moved, points: [slice], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.performanceRate == 1)
    #expect(model.playbackSnapshot?.a.sourceFrame == position)
    let down = SurfacePoint(id: 2, x: 0.6, y: 0.9)
    session.handle(.init(phase: .began, points: [slice, down], ending: []), model: model, deck: .a, span: 64000)
    #expect(abs((model.playbackSnapshot?.a.performanceRate ?? 0) - pow(2, -0.8)) < 0.000001)
    session.handle(.init(phase: .ended, points: [slice, down], ending: [2]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    #expect(model.playbackSnapshot?.a.performanceRate == 1)
    #expect(model.playbackSnapshot?.a.touchStart == 56000)
    session.handle(.init(phase: .cancelled, points: [slice], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.performanceRate == 1)
    await model.finishForShutdown()
}

@Test @MainActor func superSlicerFamilyChangeCancelsHoldAndKeepsDecksIndependent() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.pitch, deck: .a)
    model.selectSuperSlicerFamily(.turntablism, deck: .b)
    let a = WaveformGestureSession()
    let b = WaveformGestureSession()
    let up = SurfacePoint(id: 1, x: 0.4, y: 0.1)
    let reverse = SurfacePoint(id: 1, x: 0.4, y: 0.9)
    a.handle(.init(phase: .began, points: [up], ending: []), model: model, deck: .a, span: 64000)
    b.handle(.init(phase: .began, points: [reverse], ending: []), model: model, deck: .b, span: 64000)
    #expect(model.playbackSnapshot?.b.performanceRate == -1)
    model.selectSuperSlicerFamily(.turntablism, deck: .a)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.b.touchActive == true)
    #expect(model.playbackSnapshot?.b.performanceRate == -1)
    a.handle(.init(phase: .moved, points: [reverse], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    a.handle(.init(phase: .ended, points: [reverse], ending: [1]), model: model, deck: .a, span: 64000)
    a.handle(.init(phase: .began, points: [reverse], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.performanceRate == -1)
    a.handle(.init(phase: .ended, points: [reverse], ending: [1]), model: model, deck: .a, span: 64000)
    b.handle(.init(phase: .ended, points: [reverse], ending: [1]), model: model, deck: .b, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.b.touchActive == false)
    await model.finishForShutdown()
}

@Test @MainActor func superSlicerBlankContactNeverReplacesValidHeldRegion() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.pitch, deck: .a)
    model.viewport[.a] = 0
    let session = WaveformGestureSession()
    let valid = SurfacePoint(id: 1, x: 0.7, y: 0.1)
    let blank = SurfacePoint(id: 2, x: 0.01, y: 0.9)
    session.handle(.init(phase: .began, points: [valid], ending: []), model: model, deck: .a, span: 64000)
    let position = model.playbackSnapshot?.a.sourceFrame
    let rate = model.playbackSnapshot?.a.performanceRate
    session.handle(.init(phase: .began, points: [valid, blank], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.sourceFrame == position)
    #expect(model.playbackSnapshot?.a.performanceRate == rate)
    session.handle(.init(phase: .ended, points: [valid, blank], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    session.handle(.init(phase: .ended, points: [blank], ending: [2]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.sourceFrame == position)
    #expect(model.playbackSnapshot?.a.performanceRate == 1)
    await model.finishForShutdown()
}

@Test @MainActor func loopStutterChangesLengthWithoutRetriggeringInsideOneRow() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.loopStutter, deck: .a)
    let session = WaveformGestureSession()
    let full = SurfacePoint(id: 1, x: 0.4, y: 0.1)
    session.handle(.init(phase: .began, points: [full], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchEnd == 64000)
    for (y, end) in [(0.2, 64000.0), (0.5, 60000.0), (0.6, 60000.0), (0.9, 58000.0)] {
        let previousEnd = model.playbackSnapshot?.a.touchEnd
        _ = model.playback.core.renderOffline(frames: 128)
        model.refreshPlayback()
        let advanced = try #require(model.playbackSnapshot?.a.sourceFrame)
        let point = SurfacePoint(id: 1, x: 0.4, y: y)
        session.handle(.init(phase: .moved, points: [point], ending: []), model: model, deck: .a, span: 64000)
        let state = try #require(model.playbackSnapshot?.a)
        #expect(state.touchStart == 56000 && state.touchEnd == end && state.performanceRate == 1)
        #expect(state.sourceFrame == (previousEnd == end ? advanced : 56000))
    }
    let last = SurfacePoint(id: 1, x: 0.4, y: 0.9)
    session.handle(.init(phase: .ended, points: [last], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.performanceRate == 1)
    await model.finishForShutdown()
}

@Test @MainActor func loopStutterNewestContactRestoresTheOlderLength() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.loopStutter, deck: .a)
    let other = try #require(model.playbackSnapshot?.b)
    let session = WaveformGestureSession()
    let full = SurfacePoint(id: 1, x: 0.4, y: 0.1)
    let quarter = SurfacePoint(id: 2, x: 0.4, y: 0.9)
    session.handle(.init(phase: .began, points: [full], ending: []), model: model, deck: .a, span: 64000)
    session.handle(.init(phase: .began, points: [full, quarter], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchEnd == 58000)
    session.handle(.init(phase: .ended, points: [full, quarter], ending: [2]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == true && model.playbackSnapshot?.a.touchEnd == 64000)
    #expect(model.playbackSnapshot?.b == other)
    session.handle(.init(phase: .cancelled, points: [full], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.performanceRate == 1)
    await model.finishForShutdown()
}

@Test @MainActor func loopStutterClipsPlayableLengthsAndKeepsOneFrameMinimum() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.selectSuperSlicerFamily(.loopStutter, deck: .a)
    let frameCount = Double(try #require(model.track(.a)).analysis.frameCount)
    for (center, x, baseStart, baseEnd) in [
        (4500.0, 0.4, 0.0, 4500.0), (frameCount - 1000, 0.5, frameCount - 1000, frameCount),
        (frameCount - 1, 0.5, frameCount - 1, frameCount),
    ] {
        for (y, fraction) in [(0.1, 1.0), (0.5, 0.5), (0.9, 0.25)] {
            model.viewport[.a] = center
            let session = WaveformGestureSession()
            let point = SurfacePoint(id: 1, x: x, y: y)
            session.handle(.init(phase: .began, points: [point], ending: []), model: model, deck: .a, span: 64000)
            let state = try #require(model.playbackSnapshot?.a)
            #expect(state.touchActive && state.touchStart == baseStart)
            #expect(state.touchEnd == min(baseEnd, baseStart + max(1, (baseEnd - baseStart) * fraction)))
            #expect(state.touchEnd - state.touchStart >= 1 && state.touchEnd <= frameCount)
            session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a, span: 64000)
        }
    }
    await model.finishForShutdown()
}

@Test @MainActor func loopStutterRowChangeRetainsSlicerQuantizeAndCancelsPendingEntry() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.performance.slicerQuantize = true
    model.performance.quantize = 4
    model.selectSuperSlicerFamily(.loopStutter, deck: .a)
    let session = WaveformGestureSession()
    let full = SurfacePoint(id: 1, x: 0.4, y: 0.1)
    let half = SurfacePoint(id: 1, x: 0.4, y: 0.5)
    session.handle(.init(phase: .began, points: [full], ending: []), model: model, deck: .a, span: 64000)
    session.handle(.init(phase: .moved, points: [half], ending: []), model: model, deck: .a, span: 64000)
    let pending = try #require(model.playbackSnapshot?.a)
    #expect(pending.jumpPending && pending.pendingTouchEnd == 60000 && pending.pendingTouchRate == 1)
    session.handle(.init(phase: .ended, points: [half], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.jumpPending == false)
    _ = model.playback.core.renderOffline(frames: 128)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.touchActive == false)
    await model.finishForShutdown()
}

@Test(arguments: [SuperSlicerFamily.loopStutter, .turntablism]) @MainActor
func superSlicerFluxReleaseKeepsOtherDeckSamplesAndClockExact(_ family: SuperSlicerFamily) async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let initial = try #require(model.playbackSnapshot)
    let asset = try #require(model.playback.core.asset(generation: initial.b.generation))
    let track = try #require(model.track(.b))
    let reference = try SampleTransport(sampleRate: model.playback.core.sampleRate)
    let generation = try reference.load(
        asset, deck: .b, grid: track.grid, synced: initial.b.synced, keylock: initial.b.keylock)
    #expect(reference.processControlsWhileIdle())
    model.setMixer(.crossfader, value: 1)
    model.setMixer(.volume, value: 0, deck: .a)
    try reference.setMixer(.crossfader, value: 1)
    try model.playback.play(.b)
    try reference.play(deck: .b, generation: generation)
    #expect(reference.processControlsWhileIdle())
    _ = model.playback.core.renderOffline(frames: 512)
    _ = reference.renderOffline(frames: 512)
    model.refreshPlayback()
    model.selectSuperSlicerFamily(family, deck: .a)
    model.perform(.flux, deck: .a, enabled: true)
    let session = WaveformGestureSession()
    let rows = family == .turntablism ? [0.5, 0.5, 0.9, 0.3] : [0.1, 0.5, 0.9, 0.2]
    for (index, y) in rows.enumerated() {
        let point = SurfacePoint(id: 1, x: index == 1 ? 0.41 : 0.4, y: y)
        session.handle(
            .init(phase: index == 0 ? .began : .moved, points: [point], ending: []), model: model, deck: .a, span: 64000
        )
        for _ in 0..<4 {
            let actual = model.playback.core.renderOffline(frames: 256)
            let expected = reference.renderOffline(frames: 256)
            #expect(actual.left == expected.left && actual.right == expected.right)
            #expect(model.playback.core.snapshot()?.masterBeat == reference.snapshot()?.masterBeat)
            #expect(model.playback.core.snapshot()?.b.sourceFrame == reference.snapshot()?.b.sourceFrame)
        }
        model.refreshPlayback()
    }
    let continuing = try #require(model.playbackSnapshot?.a.continuingFrame)
    let point = SurfacePoint(id: 1, x: 0.4, y: 0.2)
    session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.sourceFrame == continuing)
    #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.performanceRate == 1)
    let actual = model.playback.core.renderOffline(frames: 512)
    let expected = reference.renderOffline(frames: 512)
    #expect(actual.left == expected.left && actual.right == expected.right)
    await model.finishForShutdown()
}

@Test @MainActor func loopStutterContextChangesDoNotReuseTheHeldContact() async throws {
    let (model, root) = try await superSlicerFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let point = SurfacePoint(id: 1, x: 0.4, y: 0.9)
    for change in 0..<3 {
        if model.editing.contains(.a) { model.toggleGridEditing(deck: .a) }
        model.selectSuperSlicerFamily(.loopStutter, deck: .a)
        let session = WaveformGestureSession()
        session.handle(.init(phase: .began, points: [point], ending: []), model: model, deck: .a, span: 64000)
        #expect(model.playbackSnapshot?.a.touchActive == true && model.playbackSnapshot?.a.touchEnd == 58000)
        switch change {
        case 0: model.selectSuperSlicerFamily(.pitch, deck: .a)
        case 1: model.toggleGridEditing(deck: .a)
        default: model.toggleFreeze(deck: .a)
        }
        session.handle(.init(phase: .moved, points: [point], ending: []), model: model, deck: .a, span: 64000)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a, span: 64000)
    }
    if model.editing.contains(.a) { model.toggleGridEditing(deck: .a) }
    model.selectSuperSlicerFamily(.loopStutter, deck: .a)
    let held = WaveformGestureSession()
    held.handle(.init(phase: .began, points: [point], ending: []), model: model, deck: .a, span: 64000)
    let oldID = model.loaded[.a]
    model.stopAudio()
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
        .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-b-128.wav")
    await model.importFiles([source])
    let replacement = try #require(model.library.tracks.first(where: { $0.id != oldID }))
    model.load(trackID: replacement.id, deck: .a)
    await model.flushWrites()
    let newGeneration = try #require(model.playbackSnapshot?.a.generation)
    held.handle(.init(phase: .moved, points: [point], ending: []), model: model, deck: .a, span: 64000)
    #expect(model.loaded[.a] == replacement.id && model.playbackSnapshot?.a.generation == newGeneration)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    held.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a, span: 64000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    await model.finishForShutdown()
}

@Test(.timeLimit(.minutes(1)), arguments: [false, true]) @MainActor
func loopStutterColdRowChangesKeepAudioUntilReadyAndCancelSafely(_ cancel: Bool) async throws {
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
        .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = try WorkspaceStore(root: root)
    try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent("source.wav"))
    let analysis = AudioAnalysis(
        implementation: "stutter-cold-fixture", configurationID: "fixture",
        contentSHA256: try AudioAnalyzer.sha256(url: source), sampleRate: 44100, frameCount: 705600, channelCount: 2,
        waveformFramesPerBin: 441, waveform: [], bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1, key: nil,
        keyConfidence: 0, chroma: [], timbre: [])
    let track = try Track(title: "Stutter cold fixture", mediaFilename: "source.wav", analysis: analysis)
    let streamed = try PlaybackController(offline: true, streamingPlayback: true)
    let reference = try PlaybackController(offline: true)
    defer {
        streamed.stopAudio()
        reference.stopAudio()
        try? FileManager.default.removeItem(at: root)
    }
    try await streamed.load(track: track, store: store, deck: .a)
    try await reference.load(track: track, store: store, deck: .a)
    try streamed.setMasterBPM(180)
    try reference.setMasterBPM(180)
    try streamed.play(.a)
    try reference.play(.a)
    for _ in 0..<32 {
        _ = streamed.core.renderOffline(frames: 512)
        _ = reference.core.renderOffline(frames: 512)
    }
    let model = try ReplicaModel(root: root, playback: streamed)
    model.library.tracks = [track]
    model.loaded[.a] = track.id
    model.frozen.insert(.a)
    model.superSlicerFamilies[.a] = .loopStutter
    model.viewport[.a] = 12 * 44100
    model.performance.slicerQuantize = false
    model.refreshPlayback()
    let session = WaveformGestureSession()
    let half = SurfacePoint(id: 1, x: 0.55, y: 0.5)
    let quarter = SurfacePoint(id: 1, x: 0.55, y: 0.9)
    session.handle(.init(phase: .began, points: [half], ending: []), model: model, deck: .a, span: 8 * 44100)
    #expect(streamed.preparingSourceDecks.contains(.a) && model.playbackSnapshot?.a.touchActive == false)
    let continuing = streamed.core.renderOffline(frames: 512)
    let expected = reference.core.renderOffline(frames: 512)
    #expect(continuing.left == expected.left && continuing.right == expected.right)
    session.handle(.init(phase: .moved, points: [quarter], ending: []), model: model, deck: .a, span: 8 * 44100)
    if cancel {
        session.handle(.init(phase: .ended, points: [quarter], ending: [1]), model: model, deck: .a, span: 8 * 44100)
    }
    await streamed.flushSourcePreparations()
    model.refreshPlayback()
    if cancel {
        #expect(model.playbackSnapshot?.a.touchActive == false)
    } else {
        #expect(model.playbackSnapshot?.a.touchActive == true)
        #expect(model.playbackSnapshot?.a.touchStart == 12.0 * 44100)
        #expect(model.playbackSnapshot?.a.touchEnd == 12.25 * 44100)
        try reference.perform(.touch, deck: .a, value: 12 * 44100, end: 12.25 * 44100, touchRate: 1)
    }
    for _ in 0..<32 {
        let actual = streamed.core.renderOffline(frames: 256)
        let expected = reference.core.renderOffline(frames: 256)
        #expect(actual.left == expected.left && actual.right == expected.right)
        try await Task.sleep(for: .milliseconds(1))
    }
    #expect(streamed.sourcePreparationFailures == 0 && !streamed.core.streamingSummary().continuityFailed)
    if !cancel {
        session.handle(.init(phase: .ended, points: [quarter], ending: [1]), model: model, deck: .a, span: 8 * 44100)
    }
    await model.finishForShutdown()
}
