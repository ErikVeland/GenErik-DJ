import Foundation
import Testing
@testable import TDJCore

private func performanceRig() throws -> (SampleTransport,UInt64) {
    let core=try SampleTransport(sampleRate:8000)
    let samples=(0..<32000).flatMap { index -> [Float] in [Float(index%100)/500, -Float(index%100)/500] }
    let asset=try PCMAsset(interleavedStereo:samples,sampleRate:8000)
    let generation=try core.load(asset,deck:.a,grid:BeatGrid(bpm:120,anchorFrame:0,sampleRate:8000))
    core.processControlsWhileIdle(); _=core.acknowledgements()
    return (core,generation)
}
@Test func performanceLoopWrapsAndFluxReturnsToContinuingTime() throws {
    let (core,g)=try performanceRig()
    try core.play(deck:.a,generation:g)
    _=core.renderOffline(frames:1000)
    try core.perform(.flux,deck:.a,generation:g)
    try core.perform(.loop,deck:.a,generation:g,value:1000,end:2000)
    let audio=core.renderOffline(frames:2500)
    #expect(core.snapshot()?.a.sourceFrame == 1500)
    #expect(core.snapshot()?.a.continuingFrame == 3500)
    #expect(audio.left.allSatisfy { $0.isFinite })
    #expect(zip(audio.left,audio.right).allSatisfy { abs($0+$1)<0.000001 })
    try core.perform(.loop,deck:.a,generation:g,enabled:false)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.sourceFrame == 3500)
    #expect(core.snapshot()?.a.loopEnabled == false)
}
@Test func performanceJumpExecutesAtSampleBoundaryAndRejectsStaleActions() throws {
    let (core,g)=try performanceRig()
    try core.play(deck:.a,generation:g); _=core.renderOffline(frames:1000)
    try core.perform(.jump,deck:.a,generation:g,value:12000,end:1)
    _=core.renderOffline(frames:3000)
    #expect(core.snapshot()?.a.sourceFrame == 4000)
    _=core.renderOffline(frames:1)
    #expect(core.snapshot()?.a.sourceFrame == 12001)
    try core.perform(.loop,deck:.a,generation:g+1,value:0,end:4000)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .stale)
    #expect(core.snapshot()?.a.loopEnabled == false)
}
@Test func performanceTouchAuditionsStoppedDeckAndPanicClearsTemporaryRate() throws {
    let (core,g)=try performanceRig()
    try core.perform(.touch,deck:.a,generation:g,value:4000)
    _=core.renderOffline(frames:100)
    #expect(core.snapshot()?.a.phase == .playing)
    try core.perform(.rate,deck:.a,generation:g,value:-1)
    _=core.renderOffline(frames:50)
    #expect(core.snapshot()?.a.sourceFrame == 4050)
    try core.perform(.touch,deck:.a,generation:g,enabled:false)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.phase == .paused)
    #expect(core.snapshot()?.a.performanceRate == 1)
    try core.perform(.touch,deck:.a,generation:g,value:5000)
    try core.perform(.rate,deck:.a,generation:g,value:0)
    try core.stopAll(); core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.touchActive == false)
    #expect(core.snapshot()?.a.performanceRate == 1)
}
@Test func performanceRejectsInvalidLoopsWithoutChangingExistingLoop() throws {
    let (core,g)=try performanceRig()
    try core.perform(.loop,deck:.a,generation:g,value:1000,end:2000)
    try core.perform(.loop,deck:.a,generation:g,value:2000,end:1000)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .invalid)
    #expect(core.snapshot()?.a.loopStart == 1000)
    #expect(core.snapshot()?.a.loopEnd == 2000)
}
@Test func performanceCuesAndPreferencesSurviveRestart() throws {
    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:url) }
    var data=PerformancePreparation()
    data.cues["track"]=[0:.init(frame:20),7:.init(frame:100,loopEnd:200)]
    data.quantize=0.25; data.freezeOnLoad=true
    try data.save(to:url)
    let restored=try PerformancePreparation.load(from:url)
    #expect(restored.cues == data.cues)
    #expect(restored.quantize == 0.25)
    #expect(restored.freezeOnLoad)
}

@Test func performanceKeylockNeverReadsBeyondLoopOrSlice() throws {
    for slice in [false,true] {
        let core=try SampleTransport(sampleRate:8000)
        var samples=[Float](repeating:0.3,count:32000*2)
        for frame in 8000..<12000 { samples[frame*2]=0; samples[frame*2+1]=0 }
        let g=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:8000),deck:.a,
                            grid:BeatGrid(bpm:120,anchorFrame:0,sampleRate:8000),keylock:true)
        try core.setMasterBPM(150)
        try core.perform(slice ? .touch : .loop,deck:.a,generation:g,value:8000,end:12000)
        if !slice { try core.play(deck:.a,generation:g) }
        let audio=core.renderOffline(frames:24000)
        #expect(audio.left.allSatisfy { abs($0)<0.000001 })
        #expect(audio.right.allSatisfy { abs($0)<0.000001 })
    }
}
@Test func performanceDelayTailContinuesAfterPauseAndEffectsRemainFinite() throws {
    let (core,g)=try performanceRig()
    try core.setEffect(0,slot:0,x:0,y:0.7,enabled:true,deck:.a)
    try core.play(deck:.a,generation:g); _=core.renderOffline(frames:7000)
    try core.play(deck:.a,generation:g)
    let tail=core.renderOffline(frames:1500)
    #expect(tail.left.contains { abs($0)>0.0001 })
    #expect(tail.left.allSatisfy { $0.isFinite })
    for kind in 0..<5 {
        for slot in 0..<3 { try core.setEffect(kind,slot:slot,x:1,y:1,enabled:true,deck:.a) }
        let output=core.renderOffline(frames:1000)
        #expect(output.left.allSatisfy { $0.isFinite && abs($0)<10 })
    }
}

@Test func performanceEffectChangesCannotReplayInvalidatedHistory() throws {
    let (core,g)=try performanceRig()
    try core.setEffect(0,slot:0,x:0,y:1,enabled:true,deck:.a)
    try core.play(deck:.a,generation:g)
    _=core.renderOffline(frames:24000)
    try core.play(deck:.a,generation:g)
    // Gater has no tail. Let the mixer settle while the source remains paused.
    try core.setEffect(3,slot:0,x:0,y:1,enabled:true,deck:.a)
    _=core.renderOffline(frames:4000)
    for kind in [0,1,2,4,0] {
        try core.setEffect(kind,slot:0,x:0,y:1,enabled:true,deck:.a)
        let output=core.renderOffline(frames:20000)
        #expect(output.left.allSatisfy { abs($0)<0.000001 })
        #expect(output.right.allSatisfy { abs($0)<0.000001 })
    }
}

@Test func performanceEffectChangesSmoothTheOutputBoundary() throws {
    for changeKind in [false,true] {
        let core=try SampleTransport(sampleRate:8000)
        let asset=try PCMAsset(interleavedStereo:[Float](repeating:0.25,count:80000),sampleRate:8000)
        let g=try core.load(asset,deck:.a,grid:BeatGrid(bpm:120,anchorFrame:0,sampleRate:8000))
        try core.setEffect(0,slot:0,x:0,y:1,enabled:true,deck:.a)
        try core.play(deck:.a,generation:g)
        let before=core.renderOffline(frames:12000).left.last!
        try core.setEffect(changeKind ? 3 : 0,slot:0,x:changeKind ? 0 : 1,y:1,enabled:true,deck:.a)
        let changed=core.renderOffline(frames:100).left
        #expect(abs(changed[0]-before)<0.01)
        #expect(changed.allSatisfy { $0.isFinite })
        #expect(zip(changed,changed.dropFirst()).allSatisfy { abs($0-$1)<0.01 })
    }
}

@Test func performanceSavedLoopRecallCommitsBothBoundsAtQuantizedBoundary() throws {
    let (core,g)=try performanceRig()
    try core.play(deck:.a,generation:g); _=core.renderOffline(frames:1000)
    try core.perform(.loop,deck:.a,generation:g,value:12000,end:16000,quantum:1)
    _=core.renderOffline(frames:3000)
    #expect(core.snapshot()?.a.loopEnabled == false)
    #expect(core.snapshot()?.a.sourceFrame == 4000)
    _=core.renderOffline(frames:1)
    #expect(core.snapshot()?.a.loopEnabled == true)
    #expect(core.snapshot()?.a.loopStart == 12000)
    #expect(core.snapshot()?.a.loopEnd == 16000)
    #expect(core.snapshot()?.a.sourceFrame == 12001)
}

@Test func documentedQuantizeMenuDefaultAndLegacyMigrationPreserveCues() throws {
    #expect(PerformancePreparation.quantizeSizes == [0.25,0.5,1,4])
    #expect(PerformancePreparation().quantize == 0.5)
    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:url) }
    for legacy in [0.0,2,8] {
        var value=PerformancePreparation()
        value.quantize=legacy; value.cues["track"]=[3:.init(frame:4000,loopEnd:8000)]
        try JSONEncoder().encode(value).write(to:url)
        let migrated=try PerformancePreparation.load(from:url)
        #expect(migrated.quantize == 0.5)
        #expect(migrated.cues == value.cues)
        try migrated.save(to:url)
        #expect(try PerformancePreparation.load(from:url).quantize == 0.5)
    }
}

@Test func savedLoopRecallJumpsToStartWhenPausedInsideExistingLoop() throws {
    let (core,g)=try performanceRig()
    try core.play(deck:.a,generation:g)
    _=core.renderOffline(frames:10)
    try core.play(deck:.a,generation:g)
    try core.perform(.jump,deck:.a,generation:g,value:1500)
    try core.perform(.loop,deck:.a,generation:g,value:1000,end:3000)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.sourceFrame == 1500)
    try core.perform(.loop,deck:.a,generation:g,value:1000,end:3000,quantum:0.5)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.sourceFrame == 1000)
    #expect(core.snapshot()?.a.phase == .paused)
    #expect(core.snapshot()?.a.loopEnabled == true)
}

@Test func loopSizesAreIndependentAndMigrateFromLegacyPreference() throws {
    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:url) }
    let legacy=PerformancePreparation()
    try legacy.save(to:url)
    var settings=try PerformancePreparation.load(from:url)
    #expect(settings.loopBeats(for:.a) == 4)
    #expect(settings.loopBeats(for:.b) == 4)
    settings.setLoopBeats(8,for:.a)
    settings.setLoopBeats(0.5,for:.b)
    try settings.save(to:url)
    let restored=try PerformancePreparation.load(from:url)
    #expect(restored.loopBeats(for:.a) == 8)
    #expect(restored.loopBeats(for:.b) == 0.5)
}
