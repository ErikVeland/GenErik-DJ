import Foundation
import Testing
@testable import TDJCore

private func stereoAsset(rate: Double = 48000, frames: Int = 480000, left: Float, right: Float) throws -> PCMAsset {
    var samples = [Float](repeating: 0, count: frames * 2)
    for i in 0..<frames { samples[2*i] = left; samples[2*i+1] = right }
    return try PCMAsset(interleavedStereo: samples, sampleRate: rate)
}

private func pair(rate: Double = 48000, bSource: Double = 0) throws -> (SampleTransport, UInt64, UInt64) {
    let core = try SampleTransport(sampleRate: rate)
    let a = try core.load(stereoAsset(left: 0.2, right: 0), deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000))
    let b = try core.load(stereoAsset(left: 0, right: 0.2), deck: .b,
        grid: BeatGrid(bpm: 128, anchorFrame: 0, sampleRate: 48000), sourceFrame: bSource)
    core.processControlsWhileIdle(); _ = core.acknowledgements()
    return (core, a, b)
}

private func expectStartSettlesWithoutOvershoot(_ core: SampleTransport) {
    let ramp=core.renderOffline(frames:95).right
    #expect(ramp.first! > 0)
    #expect(ramp.allSatisfy { $0 > 0 && $0 <= 0.1 })
    #expect(zip(ramp,ramp.dropFirst()).allSatisfy { $0 <= $1 })
    #expect(ramp.last == 0.1)
}

@Test func earlyPlayIsSilentAndStationaryUntilTheNextBar() throws {
    let (core, a, b) = try pair(bSource: 1234.5)
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 36000)
    #expect(core.snapshot()?.masterBeat == 1.5)
    try core.play(deck: .b, generation: b); core.processControlsWhileIdle()
    #expect(core.snapshot()?.b.phase == .queued)
    #expect(core.snapshot()?.b.targetBeat == 4)
    #expect(core.snapshot()?.b.sourceFrame == 1234.5)
    #expect(try #require(core.snapshot()?.b.leadInSourceFrame) < 1234.5)
    let waiting = core.renderOffline(frames: 60000)
    #expect(waiting.right.allSatisfy { $0 == 0 })
    #expect(core.snapshot()?.b.sourceFrame == 1234.5)
    let started = core.renderOffline(frames: 1)
    #expect(started.right[0] == 0)
    #expect(core.snapshot()?.b.phase == .playing)
    #expect(core.snapshot()?.b.lastStartOutputFrame == 96000)
    #expect(core.snapshot()?.b.sourceFrame == 1235.4375)
    expectStartSettlesWithoutOvershoot(core)
}

@Test func launchesDoNotDependOnAudioBlockSize() throws {
    for block in [1, 127, 256, 511, 1024, 4096] {
        let (core, a, b) = try pair()
        try core.play(deck: .a, generation: a); _ = core.renderOffline(frames: 36000)
        try core.play(deck: .b, generation: b)
        var rendered = 0
        while rendered < 61000 {
            let size = min(block, 61000-rendered)
            let result = core.renderOffline(frames: size)
            for (i, sample) in result.right.enumerated() {
                let outputFrame=36000+rendered+i
                #expect((sample == 0) == (outputFrame <= 96000))
                if outputFrame >= 96096 { #expect(sample == 0.1) }
            }
            rendered += size
        }
        #expect(core.snapshot()?.b.lastStartOutputFrame == 96000)
    }
}

@Test func aTempoChangeKeepsPhaseAndRetimesTheMusicalTarget() throws {
    let (core, a, b) = try pair()
    try core.play(deck: .a, generation: a); _ = core.renderOffline(frames: 36000)
    try core.play(deck: .b, generation: b); _ = core.renderOffline(frames: 24000)
    let beat = core.snapshot()?.masterBeat
    try core.setMasterBPM(128); core.processControlsWhileIdle()
    #expect(core.snapshot()?.masterBeat == beat)
    #expect(core.snapshot()?.b.targetBeat == 4)
    #expect(core.snapshot()?.a.speed == 128.0 / 120)
    #expect(core.renderOffline(frames: 33750).right.allSatisfy { $0 == 0 })
    #expect(core.renderOffline(frames: 1).right[0] == 0)
    #expect(core.snapshot()?.b.lastStartOutputFrame == 93750)
    expectStartSettlesWithoutOvershoot(core)
}

@Test func pickupAndDownbeatDoNotGetRelabelledAsSourceZero() throws {
    let core = try SampleTransport()
    let a = try core.load(stereoAsset(left: 0.2, right: 0), deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 12000, sampleRate: 48000))
    let b = try core.load(stereoAsset(left: 0, right: 0.2), deck: .b,
        grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000))
    try core.play(deck: .a, generation: a); core.processControlsWhileIdle()
    #expect(core.snapshot()?.masterBeat == -0.5)
    try core.play(deck: .b, generation: b)
    #expect(core.renderOffline(frames: 12000).right.allSatisfy { $0 == 0 })
    _ = core.renderOffline(frames: 1)
    #expect(core.snapshot()?.b.lastStartOutputFrame == 12000)
}

@Test func unsyncedPlaybackAndPauseUseIndependentSourcePositions() throws {
    let (core, a, b) = try pair()
    try core.setSync(false, deck: .b, generation: b)
    try core.play(deck: .a, generation: a); try core.play(deck: .b, generation: b)
    try core.setMasterBPM(132)
    _ = core.renderOffline(frames: 48000)
    #expect(abs(try #require(core.snapshot()?.a.sourceFrame) - 52800) < 0.001)
    #expect(core.snapshot()?.b.sourceFrame == 48000)
    try core.play(deck: .b, generation: b); core.processControlsWhileIdle()
    let position = core.snapshot()?.b.sourceFrame
    _ = core.renderOffline(frames: 1000)
    #expect(core.snapshot()?.b.phase == .paused)
    #expect(core.snapshot()?.b.sourceFrame == position)
}

@Test func queuedMutationsStayGatedWhileTheOtherDeckCanPause() throws {
    let (core, a, b) = try pair()
    try core.play(deck: .a, generation: a); _ = core.renderOffline(frames: 36000)
    try core.play(deck: .b, generation: b); core.processControlsWhileIdle(); _ = core.acknowledgements()
    try core.seek(frame: 10, deck: .b, generation: b)
    try core.setSync(false, deck: .b, generation: b)
    try core.play(deck: .a, generation: a)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().map(\.error) == [.unresolved, .unresolved, nil])
    #expect(core.snapshot()?.a.phase == .paused)
    #expect(core.snapshot()?.b.phase == .queued)
    #expect(core.snapshot()?.b.targetBeat == 4)
    #expect(core.snapshot()?.b.sourceFrame == 0)
    let beat = core.snapshot()?.masterBeat
    try core.play(deck: .b, generation: b)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(core.snapshot()?.a.phase == .paused)
    #expect(core.snapshot()?.b.phase == .paused)
    #expect(core.snapshot()?.b.targetBeat == nil)
    #expect(core.snapshot()?.b.sourceFrame == 0)
    #expect(core.snapshot()?.masterBeat == beat)
}

@Test func stalePlayCannotStartAReplacementTrackAndRetiredAssetsRelease() throws {
    let core = try SampleTransport()
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    var asset: PCMAsset? = try stereoAsset(left: 0.2, right: 0)
    weak var weakAsset = asset
    let old = try core.load(try #require(asset), deck: .a, grid: grid)
    asset = nil
    #expect(weakAsset != nil)
    let new = try core.load(stereoAsset(left: 0, right: 0.2), deck: .a, grid: grid)
    try core.play(deck: .a, generation: old); core.processControlsWhileIdle()
    let acknowledgements = core.acknowledgements()
    #expect(acknowledgements.last?.error == .stale)
    #expect(weakAsset == nil)
    #expect(core.snapshot()?.a.generation == new)
    #expect(core.snapshot()?.a.phase == .ready)
}

@Test func sampleRatesAndEndOfFileStayWithinSourceBounds() throws {
    for rate in [44100.0, 48000, 96000] {
        let core = try SampleTransport(sampleRate: rate)
        let generation = try core.load(stereoAsset(rate: 44100, frames: 4410, left: 0.2, right: 0), deck: .a,
            grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 44100))
        try core.play(deck: .a, generation: generation)
        _ = core.renderOffline(frames: Int(rate))
        #expect(core.snapshot()?.a.phase == .ended)
        #expect(core.snapshot()?.a.sourceFrame == 4410)
        #expect(core.snapshot()?.clockRunning == false)
    }
}

@Test func queueBackpressureIsReportedAndPanicClearsPendingAudio() throws {
    let (core, a, b) = try pair()
    try core.play(deck: .a, generation: a); _ = core.renderOffline(frames: 100)
    try core.play(deck: .b, generation: b); core.processControlsWhileIdle()
    try core.stopAll(); core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.phase == .paused)
    #expect(core.snapshot()?.b.phase == .paused)
    let stopped=core.renderOffline(frames:100).left
    #expect(stopped.allSatisfy { $0 >= 0 && $0 <= 0.1 })
    #expect(stopped.suffix(4).allSatisfy { $0 == 0 })
    var full = false
    for _ in 0..<200 { do { try core.setMasterBPM(120) } catch { #expect(error as? TransportError == .queueFull); full = true; break } }
    #expect(full)
    core.processControlsWhileIdle(); _ = core.acknowledgements()
    #expect(core.snapshot()?.masterBPM == 120)
}

@Test func strictNextBoundaryIsAnExplicitDevelopmentRule() throws {
    for (request, target) in [(95999,96000), (96000,192000), (96001,192000)] {
        let (core,a,b) = try pair()
        try core.play(deck: .a, generation: a); _ = core.renderOffline(frames: request)
        try core.play(deck: .b, generation: b)
        _ = core.renderOffline(frames: target-request+1)
        #expect(core.snapshot()?.b.lastStartOutputFrame == UInt64(target))
    }
}

@Test func repeatedTempoEpochsKeepAnIntegralLaunchAtItsExactSample() throws {
    let (core,a,b) = try pair()
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 24000)
    try core.play(deck: .b, generation: b)
    var remaining = 72000
    while remaining>0 {
        try core.setMasterBPM(120)
        let count = min(127,remaining)
        _ = core.renderOffline(frames: count); remaining -= count
        _ = core.acknowledgements()
    }
    #expect(core.snapshot()?.masterBeat == 4)
    #expect(core.snapshot()?.b.phase == .queued)
    _ = core.renderOffline(frames: 1)
    #expect(core.snapshot()?.b.lastStartOutputFrame == 96000)
}

@Test func aFractionalBarCrossingBetweenBuffersStartsOnTheNextBufferFirstSample() throws {
    let (core, a, b) = try pair()
    try core.setMasterBPM(128)
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 89852)
    try core.setMasterBPM(149)
    try core.play(deck: .b, generation: b)
    // The bar crosses after the final sample, before the next buffer.
    let waiting = core.renderOffline(frames: 128)
    #expect(waiting.right.allSatisfy { $0 == 0 })
    #expect(try #require(core.snapshot()?.masterBeat) > 4)
    #expect(core.snapshot()?.b.phase == .queued)
    #expect(core.snapshot()?.b.sourceFrame == 0)
    let started = core.renderOffline(frames: 1)
    #expect(started.right[0] == 0)
    #expect(core.snapshot()?.b.phase == .playing)
    #expect(core.snapshot()?.b.lastStartOutputFrame == 89980)
    #expect(core.snapshot()?.b.sourceFrame == 149.0 / 128)
    expectStartSettlesWithoutOvershoot(core)
}

@Test func earlyPlayPrefersBarButFallsBackToBeatWhenReferenceEnds() throws {
    // 120 BPM: beat 2 begins at output frame 24,000, beat 3 at 48,000.
    for referenceLength in [60000,240000] {
        let core=try SampleTransport()
        let grid=try BeatGrid(bpm:120,anchorFrame:0,sampleRate:48000)
        let a=try core.load(stereoAsset(frames:referenceLength,left:0.2,right:0),deck:.a,grid:grid)
        let b=try core.load(stereoAsset(left:0,right:0.2),deck:.b,grid:grid)
        try core.play(deck:.a,generation:a)
        _=core.renderOffline(frames:25000)
        try core.play(deck:.b,generation:b)
        core.processControlsWhileIdle()
        let start: UInt64 = referenceLength == 60000 ? 48000 : 96000
        #expect(core.snapshot()?.b.targetBeat == Double(start)/24000)
        let waiting=core.renderOffline(frames:Int(start)-25000)
        #expect(waiting.right.allSatisfy { $0 == 0 })
        #expect(core.snapshot()?.b.sourceFrame == 0)
        let started=core.renderOffline(frames:1)
        #expect(started.right[0] == 0)
        #expect(core.snapshot()?.b.lastStartOutputFrame == start)
        expectStartSettlesWithoutOvershoot(core)
    }
}

@Test func rejectedLoadRetirementReleasesOnlyItsOwnAssetGeneration() throws {
    let core = try SampleTransport()
    let original = try stereoAsset(left: 0.2, right: 0)
    let generation = try core.load(original, deck: .a, grid: nil)
    try core.play(deck: .a, generation: generation)
    core.processControlsWhileIdle(); _ = core.acknowledgements()
    var rejected: PCMAsset? = try stereoAsset(left: 0, right: 0.2)
    weak var released = rejected
    let rejectedGeneration = try core.load(try #require(rejected), deck: .a, grid: nil)
    rejected = nil
    #expect(released != nil)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .protectedDeck)
    #expect(core.asset(generation: rejectedGeneration) == nil && released == nil)
    #expect(core.asset(generation: generation) === original)
    #expect(core.snapshot()?.a.generation == generation && core.snapshot()?.a.phase == .playing)
    let sharedRejected = try core.load(original, deck: .a, grid: nil)
    core.processControlsWhileIdle(); _ = core.acknowledgements()
    #expect(core.asset(generation: sharedRejected) == nil)
    #expect(core.asset(generation: generation) === original)
}

@Test func streamingMemoryBudgetIsFixedWithFourAssetReplacementHeadroom() {
    #expect(PCMStreamingLimits.assetPCMBytes == 32 * 1024 * 1024)
    #expect(PCMStreamingLimits.globalPCMBytes == 128 * 1024 * 1024)
    #expect(PCMStreamingLimits.globalPCMBytes / PCMStreamingLimits.assetPCMBytes == 4)
}

@Test func syncedDeckPlaysWhenOtherDeckIsUnsynced() throws {
    let (core,a,b)=try pair()
    try core.setSync(false,deck:.a,generation:a)
    try core.play(deck:.a,generation:a)
    _=core.renderOffline(frames:1024)
    _=core.acknowledgements()
    try core.play(deck:.b,generation:b)
    let audio=core.renderOffline(frames:1024)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(core.snapshot()?.b.phase == .playing)
    #expect(audio.right.contains { abs($0) > 0.01 })
}

@Test func playRestartsEndedTrackFromBeginning() throws {
    let core=try SampleTransport(sampleRate:8000)
    let asset=try stereoAsset(rate:8000,frames:2000,left:0.2,right:0.2)
    let generation=try core.load(asset,deck:.a,grid:nil,synced:false)
    try core.play(deck:.a,generation:generation)
    _=core.renderOffline(frames:2001)
    #expect(core.snapshot()?.a.phase == .ended)
    _=core.acknowledgements()
    try core.play(deck:.a,generation:generation)
    let audio=core.renderOffline(frames:200)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.a.sourceFrame == 200)
    #expect(audio.left.contains { abs($0) > 0.01 })
}

@Test func queuedDeckStartsAfterReferenceDeckPauses() throws {
    let (core,a,b)=try pair()
    try core.play(deck:.a,generation:a)
    _=core.renderOffline(frames:36000)
    try core.play(deck:.b,generation:b)
    core.processControlsWhileIdle()
    try core.play(deck:.a,generation:a)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.phase == .paused)
    #expect(core.snapshot()?.b.phase == .queued)
    #expect(core.snapshot()?.clockRunning == true)
    _=core.renderOffline(frames:60001)
    #expect(core.snapshot()?.b.phase == .playing)
    #expect(core.snapshot()?.b.lastStartOutputFrame == 96000)
}
