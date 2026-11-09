import Foundation
import Testing

@testable import TDJCore

private func persistentSyncRig(adaptive: Bool = false) throws -> (SampleTransport, UInt64, UInt64) {
    let core = try SampleTransport(sampleRate: 8000)
    let audio = try PCMAsset(interleavedStereo: [Float](repeating: 0.1, count: 256000), sampleRate: 8000)
    let a = try core.load(audio, deck: .a, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000))
    let map = BeatGridMap(
        anchors: [.init(beat: 0, frame: 500), .init(beat: 8, frame: 30500), .init(beat: 24, frame: 94500)],
        sampleRate: 8000)
    let b = try core.load(
        audio, deck: .b, grid: BeatGrid(bpm: 128, anchorFrame: 500, sampleRate: 8000),
        adaptiveMap: adaptive ? map : nil)
    try core.submit(.play(.a, a))
    core.processControlsWhileIdle()
    try core.submit(.play(.b, b))
    _ = core.renderOffline(frames: 16001)
    #expect(core.snapshot()?.b.phase == .playing)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    return (core, a, b)
}

@Test func persistentSyncRestoresTheAdaptiveGridAfterScratch() throws {
    let (core, _, b) = try persistentSyncRig(adaptive: true)
    try core.perform(.touch, deck: .b, generation: b, value: 63777, touchRate: 0, followsPosition: true)
    _ = core.renderOffline(frames: 913)
    try core.perform(.touch, deck: .b, generation: b, enabled: false)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.synced == true)
    #expect(abs(try #require(core.snapshot()?.syncPhaseError(.b))) < 0.001)
    _ = core.renderOffline(frames: 4096)
    #expect(abs(try #require(core.snapshot()?.syncPhaseError(.b))) < 0.001)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func persistentSyncBrakePreparationReservesTheCapturedSpeed() throws {
    let (core, _, b) = try persistentSyncRig()
    try core.brake(.begin, duration: 1, deck: .b, generation: b)
    _ = core.renderOffline(frames: 256)
    let state = try #require(core.snapshot())
    let targets = SourceControl.tempo(60).preparationTargets(snapshot: state, deck: .b, frames: 128000)
    #expect(try #require(targets.first).speed >= state.b.speed)
    try core.submit(.tempo(60))
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.synced == true)
    #expect(core.snapshot()?.b.speed == state.b.speed)
    try core.brake(.resume, deck: .b, generation: b)
    core.processControlsWhileIdle()
    #expect(abs(try #require(core.snapshot()?.syncPhaseError(.b))) < 0.001)
}

@Test func persistentSyncReturnsFromASubBeatLoopWithoutLosingIntent() throws {
    let (core, _, b) = try persistentSyncRig()
    try core.perform(.loop, deck: .b, generation: b, value: 11750, end: 12687.5)
    _ = core.renderOffline(frames: 913)
    #expect(core.snapshot()?.b.loopEnabled == true && core.snapshot()?.b.synced == true)
    try core.perform(.loop, deck: .b, generation: b, enabled: false)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.synced == true)
    #expect(abs(try #require(core.snapshot()?.syncPhaseError(.b))) < 0.001)
}

@Test(arguments: [0.0, 0.25, 0.5, 1.0])
func persistentSyncKeepsLoopEntryAndExitOnTheGrid(quantum: Double) throws {
    let (core, _, b) = try persistentSyncRig()
    _ = core.renderOffline(frames: 913)
    try core.perform(.loop, deck: .b, generation: b, value: 11750, end: 26750, quantum: quantum)
    core.processControlsWhileIdle()
    _ = core.renderOffline(frames: 17000)
    let loop = try #require(core.snapshot())
    #expect(loop.b.loopStart == 11750 && loop.b.loopEnd == 26750)
    #expect(loop.b.synced && loop.b.loopEnabled)
    #expect(abs(try #require(loop.syncPhaseError(.b))) < 0.001)
    try core.perform(.loop, deck: .b, generation: b, enabled: false)
    core.processControlsWhileIdle()
    #expect(abs(try #require(core.snapshot()?.syncPhaseError(.b))) < 0.001)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test(arguments: [0.0, 0.25, 1.0, 4.0])
func persistentSyncAlignsEveryJumpAtItsExecutionBeat(quantum: Double) throws {
    let (core, _, b) = try persistentSyncRig()
    try core.perform(.jump, deck: .b, generation: b, value: 23777, end: quantum)
    core.processControlsWhileIdle()
    _ = core.renderOffline(frames: 17000)
    let state = try #require(core.snapshot())
    #expect(state.b.synced)
    #expect(abs(try #require(state.syncPhaseError(.b))) < 0.001)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test(arguments: [false, true])
func persistentSyncSurvivesScratchReleaseAndCancellation(explicitlyOff: Bool) throws {
    let (core, _, b) = try persistentSyncRig()
    if explicitlyOff { try core.setSync(false, deck: .b, generation: b) }
    try core.perform(.touch, deck: .b, generation: b, value: 23777, touchRate: 0, followsPosition: true)
    _ = core.renderOffline(frames: 913)
    #expect(core.snapshot()?.b.synced == !explicitlyOff)
    try core.perform(.touch, deck: .b, generation: b, enabled: false)
    core.processControlsWhileIdle()
    let state = try #require(core.snapshot())
    #expect(!state.b.touchActive && state.b.performanceRate == 1)
    #expect(state.b.synced == !explicitlyOff)
    if explicitlyOff {
        #expect(state.b.sourceFrame == 23777)
    } else {
        #expect(abs(try #require(state.syncPhaseError(.b))) < 0.000001)
    }
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test(arguments: [false, true])
func persistentSyncSurvivesVinylStopAndResume(complete: Bool) throws {
    let (core, _, b) = try persistentSyncRig()
    try core.brake(.begin, duration: 0.2, deck: .b, generation: b)
    _ = core.renderOffline(frames: complete ? 1600 : 700)
    #expect(core.snapshot()?.b.synced == true)
    try core.brake(.resume, deck: .b, generation: b)
    _ = core.renderOffline(frames: 17000)
    let state = try #require(core.snapshot())
    #expect(state.b.phase == .playing && state.b.synced && !state.b.braking)
    #expect(abs(try #require(state.syncPhaseError(.b))) < 0.001)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func persistentSyncStopClearsAHeldGestureBeforeRestart() throws {
    let (core, _, b) = try persistentSyncRig()
    try core.perform(.touch, deck: .b, generation: b, value: 23777, touchRate: 0, followsPosition: true)
    core.processControlsWhileIdle()
    try core.submit(.play(.b, b))
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.phase == .paused)
    #expect(core.snapshot()?.b.synced == true)
    #expect(core.snapshot()?.b.touchActive == false)
    #expect(core.snapshot()?.b.performanceRate == 1)
    #expect(core.snapshot()?.b.sourceFrame == 23000)
    try core.submit(.play(.b, b))
    _ = core.renderOffline(frames: 17000)
    let state = try #require(core.snapshot())
    #expect(state.b.phase == .playing)
    #expect(abs(try #require(state.syncPhaseError(.b))) < 0.001)
}

@Test(arguments: [false, true], [false, true])
func persistentSyncStopsOnBeatWithAndWithoutAnotherPlayingDeck(solo: Bool, explicitlyOff: Bool) throws {
    let (core, a, b) = try persistentSyncRig()
    _ = core.renderOffline(frames: 913)
    if explicitlyOff { try core.setSync(false, deck: .b, generation: b) }
    if solo { try core.submit(.play(.a, a)) }
    core.processControlsWhileIdle()
    let before = try #require(core.snapshot()?.b.sourceFrame)
    try core.submit(.play(.b, b))
    core.processControlsWhileIdle()
    let stopped = try #require(core.snapshot()?.b)
    #expect(stopped.phase == .paused && stopped.synced == !explicitlyOff)
    let expected = explicitlyOff ? before : 500 + ((before - 500) / 3750).rounded() * 3750
    #expect(abs(stopped.sourceFrame - expected) < 0.000001)
    try core.submit(.play(.b, b))
    _ = core.renderOffline(frames: 17000)
    #expect(core.snapshot()?.b.phase == .playing)
    if !explicitlyOff { #expect(abs(try #require(core.snapshot()?.syncPhaseError(.b))) < 0.001) }
}

@Test(arguments: [false, true])
func persistentSyncSnapsStoppedSeeksAndCueStarts(explicitlyOff: Bool) throws {
    let (core, _, b) = try persistentSyncRig()
    try core.submit(.play(.b, b))
    if explicitlyOff { try core.setSync(false, deck: .b, generation: b) }
    try core.seek(frame: 23777, deck: .b, generation: b)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.sourceFrame == (explicitlyOff ? 23777 : 23000))
    try core.submit(.cueRecall(.b, b, frame: 23777, loopEnd: nil, quantum: 0))
    _ = core.renderOffline(frames: 17000)
    let state = try #require(core.snapshot())
    #expect(state.b.synced == !explicitlyOff && state.b.phase == .playing)
    if !explicitlyOff { #expect(abs(try #require(state.syncPhaseError(.b))) < 0.001) }
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func persistentSyncRetainsIntentWithoutAGridAndUsesAnArrivingGrid() throws {
    let core = try SampleTransport(sampleRate: 8000)
    let audio = try PCMAsset(interleavedStereo: [Float](repeating: 0.1, count: 64000), sampleRate: 8000)
    let a = try core.load(audio, deck: .a, grid: nil, synced: true)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.synced == true)
    #expect(core.snapshot()?.syncNeedsAlignment(.a) == true)
    try core.submit(.play(.a, a))
    _ = core.renderOffline(frames: 1200)
    try core.updateGrid(BeatGrid(bpm: 120, anchorFrame: 500, sampleRate: 8000), deck: .a, generation: a)
    core.processControlsWhileIdle()
    let state = try #require(core.snapshot())
    #expect(state.a.synced)
    #expect(abs(try #require(state.syncPhaseError(.a))) < 0.000001)
    try core.setSync(false, deck: .a, generation: a)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.synced == false)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func persistentSyncAndKeylockAcceptAnUnanalysedSecondDeck() throws {
    let core = try SampleTransport(sampleRate: 48000)
    let audio = try PCMAsset(interleavedStereo: [Float](repeating: 0.1, count: 480000), sampleRate: 48000)
    let a = try core.load(audio, deck: .a, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000))
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 512)
    let b = try core.load(audio, deck: .b, grid: nil, synced: true, keylock: true)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.phase == .ready)
    #expect(core.snapshot()?.b.synced == true && core.snapshot()?.b.keylock == true)
    try core.play(deck: .b, generation: b)
    _ = core.renderOffline(frames: 512)
    #expect(core.snapshot()?.b.phase == .playing)
    try core.updateGrid(BeatGrid(bpm: 120, anchorFrame: 500, sampleRate: 48000), deck: .b, generation: b)
    core.processControlsWhileIdle()
    #expect(abs(try #require(core.snapshot()?.syncPhaseError(.b))) < 0.000001)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}
