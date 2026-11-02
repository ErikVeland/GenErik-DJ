import Foundation
import Testing
@testable import TDJCore

@Test func recoveryDefaultsToLastDropAndSurvivesLegacySettings() throws {
    let original = PerformancePreparation()
    let data = try JSONEncoder().encode(original)
    #expect(try JSONDecoder().decode(PerformancePreparation.self, from: data).recovery.mode == .replayLastDrop)
    #expect(original.recovery.leadBars == 16)
}

@Test func recoveryFindsFinalDropAndExcludesTrailingSilence() throws {
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 100)
    let bins = (0..<400).map { index in
        WaveformBin(minimum: -0.5, maximum: 0.5,
            rms: index >= 320 ? 0 : (index >= 192 && index < 224 ? 0.05 : 0.5))
    }
    let plan = try #require(RecoveryPlan(waveform: bins, framesPerBin: 25, frameCount: 10000,
        timing: BeatTiming(fixed: grid)))
    #expect(plan.endFrame == 8000)
    #expect(plan.dropFrame == 5600)
    #expect(plan.mixStartFrame(leadBars: 8) == 6400)
    #expect(plan.mixStartFrame(leadBars: 16) == 4800)
}

private func recoveryTransport() throws -> (SampleTransport, UInt64) {
    let core = try SampleTransport(sampleRate: 8000)
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.2, count: 80000), sampleRate: 8000)
    let generation = try core.load(asset, deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000))
    core.processControlsWhileIdle()
    try core.play(deck: .a, generation: generation)
    core.processControlsWhileIdle()
    return (core, generation)
}

@Test func recoveryReplayWaitsForExclusiveFinalBeatBoundary() throws {
    let (core, generation) = try recoveryTransport()
    try core.armRecoveryReplay(deck: .a, generation: generation, dropFrame: 8000, endFrame: 32000)
    core.processControlsWhileIdle()
    _ = core.renderOffline(frames: 31999)
    #expect(core.snapshot()?.a.sourceFrame == 31999)
    #expect(core.snapshot()?.a.recoveryActive == false)
    _ = core.renderOffline(frames: 1)
    #expect(core.snapshot()?.a.sourceFrame == 8000)
    #expect(core.snapshot()?.a.recoveryActive == true)
    _ = core.renderOffline(frames: 24000)
    #expect(core.snapshot()?.a.sourceFrame == 8000)
    #expect(core.snapshot()?.a.phase == .playing)
}

@Test func manualPauseCancelsRecoveryReplay() throws {
    let (core, generation) = try recoveryTransport()
    try core.armRecoveryReplay(deck: .a, generation: generation, dropFrame: 8000, endFrame: 32000)
    core.processControlsWhileIdle()
    try core.play(deck: .a, generation: generation)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.recoveryArmed == false)
    #expect(core.snapshot()?.a.phase == .paused)
}

@Test(arguments: [8, 16]) func recoveryAutoMixStartsAtTheSelectedLeadAndFinishesAtEnd(bars: Int) throws {
    let leadFrames = bars * 16000
    let ending = 32000 + leadFrames
    let sampleCount = (ending + 40000) * 2
    let core = try SampleTransport(sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let a = try core.load(PCMAsset(interleavedStereo: [Float](repeating: 0.2, count: sampleCount), sampleRate: 8000), deck: .a, grid: grid)
    let b = try core.load(PCMAsset(interleavedStereo: [Float](repeating: 0.1, count: sampleCount), sampleRate: 8000), deck: .b, grid: grid)
    core.processControlsWhileIdle()
    try core.play(deck: .a, generation: a); core.processControlsWhileIdle()
    try core.armRecoveryReplay(deck: .a, generation: a, dropFrame: 8000, endFrame: Double(ending))
    try core.armRecoveryMix(deck: .a, generation: a, incomingGeneration: b, incomingFrame: 0, startFrame: 32000, endFrame: Double(ending))
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    _ = core.renderOffline(frames: 31999)
    #expect(core.snapshot()?.b.phase == .ready)
    _ = core.renderOffline(frames: 2)
    #expect(core.snapshot()?.b.phase == .playing)
    #expect(core.snapshot()?.b.lastStartOutputFrame == 32000)
    _ = core.renderOffline(frames: leadFrames - 1)
    #expect(core.snapshot()?.a.phase == .ended)
    #expect(core.snapshot()?.a.recoveryActive == false)
    #expect(core.snapshot()?.crossfader == 1)
    #expect(core.snapshot()?.b.sourceFrame == Double(leadFrames))
}

@Test func recoveryTempoChangesRetainTheSourceBoundary() throws {
    let (core, generation) = try recoveryTransport()
    try core.armRecoveryReplay(deck: .a, generation: generation, dropFrame: 8000, endFrame: 32000)
    _ = core.renderOffline(frames: 8000)
    try core.setMasterBPM(240); core.processControlsWhileIdle()
    _ = core.renderOffline(frames: 11999)
    #expect(core.snapshot()?.a.recoveryActive == false)
    _ = core.renderOffline(frames: 1)
    #expect(core.snapshot()?.a.recoveryActive == true)
    #expect(core.snapshot()?.a.sourceFrame == 8000)
}

@Test func recoveryRejectsStaleGenerationAndInvalidEndpoints() throws {
    let (core, generation) = try recoveryTransport()
    _ = core.acknowledgements()
    try core.armRecoveryReplay(deck: .a, generation: generation + 1, dropFrame: 8000, endFrame: 32000)
    try core.armRecoveryReplay(deck: .a, generation: generation, dropFrame: 32000, endFrame: 8000)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().compactMap(\.error) == [.stale, .invalid])
    #expect(core.snapshot()?.a.recoveryArmed == false)
}

@Test func recoveryDeclinesSilenceAndAcceptsAManualDrop() throws {
    let timing = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 100))
    let silent = [WaveformBin](repeating: .init(minimum: 0, maximum: 0, rms: 0), count: 400)
    #expect(RecoveryPlan(waveform: silent, framesPerBin: 25, frameCount: 10000, timing: timing) == nil)
    let steady = [WaveformBin](repeating: .init(minimum: -0.5, maximum: 0.5, rms: 0.5), count: 400)
    let fallback = try #require(RecoveryPlan(waveform: steady, framesPerBin: 25, frameCount: 10000, timing: timing))
    #expect(fallback.dropFrame == 6800)
    let plan = try #require(RecoveryPlan(waveform: steady, framesPerBin: 25, frameCount: 10000,
        timing: timing, dropOverride: 5623))
    #expect(plan.dropFrame == 5600)
}

@Test func recoveryFallbackSkipsQuietSectionStartsAndKeepsDownbeatAlignment() throws {
    let timing = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 100))
    let bins = (0..<400).map { index in
        WaveformBin(minimum: -0.5, maximum: 0.5, rms: index >= 272 ? 0.04 : 0.5)
    }
    let plan = try #require(RecoveryPlan(waveform: bins, framesPerBin: 25, frameCount: 10000, timing: timing))
    #expect(plan.dropFrame == 6600)
    let frame = try #require(plan.dropFrame)
    #expect(frame < plan.endFrame)
    #expect(timing.beat(atFrame: frame).truncatingRemainder(dividingBy: 4) == 0)
    #expect(frame < 6800)
}

@Test func recoveryFallbackHandlesShortTracksAndOffsetGrids() throws {
    let timing = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 100, downbeatOffset: 1))
    let bins = [WaveformBin](repeating: .init(minimum: -0.5, maximum: 0.5, rms: 0.5), count: 12)
    let plan = try #require(RecoveryPlan(waveform: bins, framesPerBin: 25, frameCount: 300, timing: timing))
    #expect(plan.dropFrame == 50)
    #expect(plan.endFrame == 300)
}

@Test func recoveryEndpointRemainsAvailableWithoutADropForAutoMix() throws {
    let timing = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 100))
    let steady = [WaveformBin](repeating: .init(minimum: -0.5, maximum: 0.5, rms: 0.5), count: 400)
    let plan = try #require(RecoveryPlan(waveform: steady, framesPerBin: 25, frameCount: 10000, timing: timing))
    #expect(plan.endFrame == 10000)
    #expect(plan.mixStartFrame(leadBars: 16) == 6800)
}

@Test func recoveryRefusesToAutoMixIntoAMutedDeck() throws {
    let core = try SampleTransport(sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let a = try core.load(PCMAsset(interleavedStereo: [Float](repeating: 0.2, count: 400000), sampleRate: 8000), deck: .a, grid: grid)
    let b = try core.load(PCMAsset(interleavedStereo: [Float](repeating: 0.1, count: 400000), sampleRate: 8000), deck: .b, grid: grid)
    core.processControlsWhileIdle()
    try core.setMixer(.volume, value: 0, deck: .b)
    try core.play(deck: .a, generation: a); core.processControlsWhileIdle()
    try core.armRecoveryReplay(deck: .a, generation: a, dropFrame: 8000, endFrame: 160000)
    core.processControlsWhileIdle(); _ = core.acknowledgements()
    try core.armRecoveryMix(deck: .a, generation: a, incomingGeneration: b, incomingFrame: 0, startFrame: 32000, endFrame: 160000)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().compactMap(\.error) == [.protectedDeck])
    #expect(core.snapshot()?.a.recoveryArmed == true)
    #expect(core.snapshot()?.a.recoveryMix == false)
}

@Test func recoveryIncomingPhaseMatchesAPartialFinalBar() throws {
    let timing = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 100, downbeatOffset: 1))
    let incoming = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 100, downbeatOffset: 2))
    let bins = [WaveformBin](repeating: .init(minimum: -0.5, maximum: 0.5, rms: 0.5), count: 402)
    let plan = try #require(RecoveryPlan(waveform: bins, framesPerBin: 25, frameCount: 10050, timing: timing))
    let start = try #require(plan.mixStartFrame(leadBars: 8))
    let frame = try #require(plan.incomingFrame(timing: incoming, leadBars: 8))
    let outgoingPhase = (timing.beat(atFrame: start) - 1).truncatingRemainder(dividingBy: 4)
    let incomingPhase = (incoming.beat(atFrame: frame) - 2).truncatingRemainder(dividingBy: 4)
    #expect(outgoingPhase == incomingPhase)
}
