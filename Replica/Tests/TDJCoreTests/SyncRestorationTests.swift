import Foundation
import Testing

@testable import TDJCore

private func syncRestorationRig(startSecond: Bool = true, alignEntry: Bool = false) throws -> (SampleTransport, UInt64, UInt64) {
    let core = try SampleTransport(sampleRate: 8000)
    var left = [Float](repeating: 0, count: 128000)
    var right = left
    for i in 0..<64000 {
        left[i * 2] = Float(sin(Double(i) * 0.013)) * 0.2
        right[i * 2 + 1] = Float(cos(Double(i) * 0.017)) * 0.2
    }
    let a = try core.load(
        PCMAsset(interleavedStereo: left, sampleRate: 8000), deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 1000, sampleRate: 8000))
    let b = try core.load(
        PCMAsset(interleavedStereo: right, sampleRate: 8000), deck: .b,
        grid: BeatGrid(bpm: 128, anchorFrame: 500, sampleRate: 8000, downbeatOffset: 1))
    core.processControlsWhileIdle()
    try core.play(deck: .a, generation: a)
    core.processControlsWhileIdle()
    if startSecond {
        if alignEntry {
            try core.submit(.play(.b, b))
        } else {
            try core.play(deck: .b, generation: b)
        }
        _ = core.renderOffline(frames: 1001)
        _ = core.acknowledgements()
        #expect(core.snapshot()?.b.phase == .playing)
    }
    return (core, a, b)
}

@Test func syncedSecondDeckStartsOnBeatWithAnOffsetGrid() throws {
    let (core, _, _) = try syncRestorationRig(alignEntry: true)
    let started = try #require(core.snapshot())
    #expect(started.b.lastStartOutputFrame == 1000)
    #expect(started.b.synced && !started.syncNeedsAlignment(.b))
    #expect(abs(try #require(started.syncPhaseError(.b))) < 0.001)
}

@Test func cancellingAnAlignedEntryRetainsTheOriginalCuePosition() throws {
    let (core, _, b) = try syncRestorationRig(startSecond: false)
    try core.submit(.play(.b, b))
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.phase == .queued)
    #expect(core.snapshot()?.b.sourceFrame == 500)
    try core.submit(.play(.b, b))
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.sourceFrame == 0)
    #expect(core.snapshot()?.b.phase == .paused)
    #expect(core.snapshot()?.a.phase == .playing)
}

@Test func nearestSyncCoordinatesRespectFileAndLoopBounds() throws {
    let grid = try BeatGrid(bpm: 120, anchorFrame: 1000, sampleRate: 8000, downbeatOffset: 3)
    #expect(grid.nearestPhaseAlignedFrame(to: 10600, masterBeat: 1.25, within: 0..<18000) == 10000)
    #expect(grid.nearestPhaseAlignedFrame(to: 9500, masterBeat: 1.25, within: 0..<18000) == 10000)
    #expect(grid.nearestPhaseAlignedFrame(to: 12000, masterBeat: 1.25, within: 0..<18000) == 14000)
    #expect(grid.nearestPhaseAlignedFrame(to: -1000, masterBeat: 1.25, within: 0..<18000) == 2000)
    #expect(grid.nearestPhaseAlignedFrame(to: 17999, masterBeat: 1.25, within: 0..<18000) == 14000)
    #expect(grid.nearestPhaseAlignedFrame(to: 10100, masterBeat: 1.25, within: 9000..<11000) == 10000)
    #expect(grid.nearestPhaseAlignedFrame(to: 11500, masterBeat: 1.25, within: 11000..<12000) == nil)
    #expect(grid.nearestPhaseAlignedFrame(to: .nan, masterBeat: 1.25, within: 0..<18000) == nil)
    #expect(grid.nearestPhaseAlignedFrame(to: 10000, masterBeat: .infinity, within: 0..<18000) == nil)
    let fractional = try BeatGrid(bpm: 120, anchorFrame: 123.5, sampleRate: 8000)
    #expect(fractional.nearestPhaseAlignedFrame(to: 8000, masterBeat: -0.25, within: 0..<16000) == 7123.5)
}

@Test(arguments: [-0.25, 0.25]) func syncRestorationIsImmediateAndUsesTheSmallestJump(_ offset: Double) throws {
    let (core, _, b) = try syncRestorationRig()
    let (reference, _, referenceB) = try syncRestorationRig()
    let initial = try #require(core.snapshot())
    let grid = try #require(initial.b.grid)
    let aligned = try #require(
        grid.nearestPhaseAlignedFrame(to: 20000, masterBeat: initial.masterBeat, within: 0..<64000))
    let displaced = aligned + offset * grid.framesPerBeat
    try core.setSync(false, deck: .b, generation: b)
    try reference.setSync(false, deck: .b, generation: referenceB)
    try core.perform(.jump, deck: .b, generation: b, value: displaced)
    try reference.perform(.jump, deck: .b, generation: referenceB, value: displaced)
    core.processControlsWhileIdle()
    reference.processControlsWhileIdle()
    let before = try #require(core.snapshot())
    #expect(!before.b.synced)
    #expect(abs(try #require(before.syncPhaseError(.b))) > 0.1)
    _ = try core.submit(.restoreSync(.b, b))
    core.processControlsWhileIdle()
    let after = try #require(core.snapshot())
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(abs(after.b.sourceFrame - aligned) < 0.000001)
    #expect((after.b.sourceFrame < before.b.sourceFrame) == (offset > 0))
    #expect(after.b.synced && !after.syncNeedsAlignment(.b))
    #expect(abs(try #require(after.syncPhaseError(.b))) < 0.000000001)
    #expect(after.masterBeat == before.masterBeat && after.outputFrame == before.outputFrame)
    #expect(after.a == before.a && after.b.lastStartOutputFrame == before.b.lastStartOutputFrame)
    for _ in 0..<8 {
        let actual = core.renderOffline(frames: 512)
        let expected = reference.renderOffline(frames: 512)
        #expect(actual.left == expected.left)
    }
    #expect(abs(try #require(core.snapshot()?.syncPhaseError(.b))) < 0.000000001)
}

@Test func syncRestorationKeepsLoopAndFluxContinuation() throws {
    let (core, _, b) = try syncRestorationRig()
    try core.perform(.flux, deck: .b, generation: b)
    try core.perform(.loop, deck: .b, generation: b, value: 18000, end: 22000)
    core.processControlsWhileIdle()
    let initial = try #require(core.snapshot())
    let grid = try #require(initial.b.grid)
    let aligned = try #require(
        grid.nearestPhaseAlignedFrame(to: 20000, masterBeat: initial.masterBeat, within: 18000..<22000))
    try core.perform(.jump, deck: .b, generation: b, value: aligned + grid.framesPerBeat * 0.25)
    core.processControlsWhileIdle()
    let before = try #require(core.snapshot())
    _ = try core.submit(.restoreSync(.b, b))
    core.processControlsWhileIdle()
    let after = try #require(core.snapshot())
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(abs(after.b.sourceFrame - aligned) < 0.000001)
    #expect(after.b.loopEnabled && after.b.fluxEnabled)
    #expect(after.b.loopStart == before.b.loopStart && after.b.loopEnd == before.b.loopEnd)
    #expect(after.b.continuingFrame == before.b.continuingFrame)
    #expect(after.a == before.a && after.masterBeat == before.masterBeat)
}

@Test func syncRestorationRejectsStaleActionsAndInadmissibleLoopsWithoutMutation() throws {
    let (core, _, b) = try syncRestorationRig()
    core.processControlsWhileIdle()
    let before = try #require(core.snapshot())
    _ = try core.submit(.restoreSync(.b, b + 1))
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .stale)
    #expect(core.snapshot() == before)
    try core.perform(.loop, deck: .b, generation: b, value: 20000, end: 20100)
    core.processControlsWhileIdle()
    _ = core.acknowledgements()
    let loop = try #require(core.snapshot())
    _ = try core.submit(.restoreSync(.b, b))
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .syncUnavailable)
    #expect(core.snapshot() == loop)
}

@Test func syncRestorationDoesNotTakeOwnershipFromAHeldWaveform() throws {
    let (core, _, b) = try syncRestorationRig()
    try core.perform(.touch, deck: .b, generation: b, value: 12000)
    core.processControlsWhileIdle()
    _ = core.acknowledgements()
    let held = try #require(core.snapshot())
    #expect(held.b.touchActive)
    _ = try core.submit(.restoreSync(.b, b))
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .activePerformance)
    #expect(core.snapshot() == held)
}

@Test func syncRestorationUsesTheCurrentNativeGridAndCanEnableTempoMatching() throws {
    let (core, _, b) = try syncRestorationRig()
    try core.setSync(false, deck: .b, generation: b)
    try core.setMasterBPM(140)
    let changed = try BeatGrid(bpm: 130, anchorFrame: 763.25, sampleRate: 8000, downbeatOffset: 2)
    try core.updateGrid(changed, deck: .b, generation: b)
    try core.perform(.jump, deck: .b, generation: b, value: 19500)
    core.processControlsWhileIdle()
    let before = try #require(core.snapshot())
    #expect(before.b.grid == changed && !before.b.synced)
    let aligned = try #require(
        changed.nearestPhaseAlignedFrame(to: before.b.sourceFrame, masterBeat: before.masterBeat, within: 0..<64000))
    let planned = SourceControl.restoreSync(.b, b).preparationTargets(snapshot: before, deck: .b, frames: 64000)
    #expect(planned.first?.position == aligned)
    _ = try core.submit(.restoreSync(.b, b))
    core.processControlsWhileIdle()
    let after = try #require(core.snapshot())
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(after.b.synced && abs(after.b.speed - 140.0 / 130) < 0.000000001)
    #expect(abs(after.b.sourceFrame - aligned) < 0.000001)
    #expect(after.masterBeat == before.masterBeat && after.a == before.a)
}

@Test func syncSnapshotDecodesWithoutTheNewGridMetadata() throws {
    let (core, _, _) = try syncRestorationRig()
    let original = try #require(core.snapshot())
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    for key in ["a", "b"] {
        var deck = try #require(json[key] as? [String: Any])
        deck.removeValue(forKey: "grid")
        json[key] = deck
    }
    let decoded = try JSONDecoder().decode(PlaybackSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(decoded.a.grid == nil && decoded.b.grid == nil)
    #expect(decoded.a.sourceFrame == original.a.sourceFrame && decoded.masterBeat == original.masterBeat)
    #expect(decoded.syncPhaseError(.a) == nil)
}
