import Foundation
import Testing
@testable import TDJCore

private func brakeTone(rate: Double = 48000) throws -> PCMAsset {
    let samples=(0..<Int(rate*8)).flatMap { frame -> [Float] in
        let x=Float(0.2*sin(2 * .pi * 440*Double(frame)/rate))
        return [x,x]
    }
    return try PCMAsset(interleavedStereo:samples,sampleRate:rate)
}
private func brakingDeck(speed: Double = 1, keylock: Bool = false) throws -> (SampleTransport,UInt64) {
    let core=try SampleTransport()
    let generation=try core.load(brakeTone(),deck:.a,grid:BeatGrid(bpm:120,anchorFrame:0,sampleRate:48000),keylock:keylock)
    try core.setMasterBPM(120*speed);try core.play(deck:.a,generation:generation)
    _=core.renderOffline(frames:24000)
    return (core,generation)
}
private func frequency(_ samples: ArraySlice<Float>) -> Double {
    let indexes=samples.indices.dropFirst().filter { samples[$0-1] <= 0 && samples[$0]>0 }
    guard let first=indexes.first,let last=indexes.last,last>first else { return 0 }
    return Double(indexes.count-1)*48000/Double(last-first)
}

@Test func vinylBrakeStopsOnTheSampleClockAndLeavesSilence() throws {
    for block in [1,127,1024] {
        let (core,generation)=try brakingDeck()
        let start=try #require(core.snapshot()?.a.sourceFrame)
        try core.brake(.begin,duration:1,deck:.a,generation:generation)
        core.processControlsWhileIdle()
        #expect(core.snapshot()?.a.braking == true)
        #expect(core.snapshot()?.a.synced == false)
        var remaining=48000
        while remaining>0 { let n=min(remaining,block);_=core.renderOffline(frames:n);remaining-=n }
        let state=try #require(core.snapshot()?.a)
        #expect(state.phase == .paused)
        #expect(!state.braking)
        #expect(abs(state.sourceFrame-start-24000.5)<0.1)
        #expect(core.renderOffline(frames:256).left.allSatisfy { $0 == 0 })
        try core.play(deck:.a,generation:generation)
        _=core.renderOffline(frames:1000)
        #expect(abs(try #require(core.snapshot()?.a.sourceFrame)-state.sourceFrame-1000)<0.01)
    }
}

@Test func vinylBrakeStrengthNeverRaisesSpeedAndReleaseNeedsNoMoreEvents() throws {
    let (core,generation)=try brakingDeck()
    try core.brake(.begin,duration:1,deck:.a,generation:generation)
    _=core.renderOffline(frames:12000)
    let before=try #require(core.snapshot()?.a.brakeRate)
    try core.brake(.strength,strength:0.25,deck:.a,generation:generation)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.brakeRate == before)
    _=core.renderOffline(frames:12000)
    let eased=try #require(core.snapshot()?.a.brakeRate)
    #expect(eased<before && eased>0.6)
    try core.brake(.strength,strength:4,deck:.a,generation:generation)
    _=core.renderOffline(frames:48000)
    #expect(core.snapshot()?.a.phase == .paused)
    try core.brake(.strength,strength:0.25,deck:.a,generation:generation)
    _=core.renderOffline(frames:100)
    #expect(core.snapshot()?.a.phase == .paused)
}

@Test func vinylBrakePauseAndResumeKeepPositionTempoAndSyncOff() throws {
    for resume in [false,true] {
        let (core,generation)=try brakingDeck(speed:1.25,keylock:true)
        try core.brake(.begin,duration:1,deck:.a,generation:generation)
        _=core.renderOffline(frames:16000)
        let position=try #require(core.snapshot()?.a.sourceFrame)
        if resume { try core.brake(.resume,deck:.a,generation:generation) }
        else { try core.play(deck:.a,generation:generation) }
        core.processControlsWhileIdle()
        let state=try #require(core.snapshot()?.a)
        #expect(!state.braking && !state.synced && state.keylock)
        #expect(state.speed == 1.25)
        #expect(state.sourceFrame == position)
        #expect(state.phase == (resume ? .playing : .paused))
        _=core.renderOffline(frames:480)
        #expect(abs(try #require(core.snapshot()?.a.sourceFrame)-position-(resume ? 600:0))<0.01)
    }
}

@Test func vinylBrakeStartsFromTheAudiblePitchWithKeylock() throws {
    for locked in [false,true] {
        let (core,generation)=try brakingDeck(speed:1.25,keylock:locked)
        try core.brake(.begin,duration:5,deck:.a,generation:generation)
        let audio=core.renderOffline(frames:9600).left
        let early=frequency(audio[480..<2880]),later=frequency(audio[6000..<9000])
        let expected=440*(locked ? 1:1.25)
        #expect(abs(early/expected-1)<0.025)
        #expect(later<early)
        #expect(audio.allSatisfy { $0.isFinite })
        #expect(zip(audio,audio.dropFirst()).map { abs($0-$1) }.max()!<0.05)
    }
}

@Test func vinylBrakePreservesOtherDeckAndMasterClock() throws {
    let (core,generation)=try brakingDeck(speed:1.1)
    let b=try core.load(brakeTone(),deck:.b,grid:BeatGrid(bpm:120,anchorFrame:0,sampleRate:48000))
    try core.setSync(false,deck:.b,generation:b);try core.play(deck:.b,generation:b)
    _=core.renderOffline(frames:1000)
    let before=try #require(core.snapshot())
    try core.brake(.begin,duration:1,deck:.a,generation:generation)
    _=core.renderOffline(frames:48000)
    let after=try #require(core.snapshot())
    #expect(after.masterBPM == before.masterBPM)
    #expect(abs(after.masterBeat-before.masterBeat-2.2)<1e-8)
    #expect(after.b.sourceFrame-before.b.sourceFrame == 48000)
    #expect(after.b.phase == .playing)
}

@Test func vinylBrakeRejectsInvalidDurationAndActiveScratch() throws {
    let (core,generation)=try brakingDeck()
    for duration in [Double.nan,0,6] {
        try core.brake(.begin,duration:duration,deck:.a,generation:generation)
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().last?.error == .invalid)
        #expect(core.snapshot()?.a.braking == false)
    }
    try core.perform(.touch,deck:.a,generation:generation,value:24000)
    core.processControlsWhileIdle()
    try core.brake(.begin,deck:.a,generation:generation)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .activePerformance)
}

@Test func vinylBrakeKeepsReverbTailsAndSupportsBothDecks() throws {
    let (core,a)=try brakingDeck()
    let b=try core.load(brakeTone(),deck:.b,grid:nil,synced:false)
    try core.play(deck:.b,generation:b)
    try core.setEffect(1,slot:0,x:0.8,y:0.8,enabled:true,deck:.a)
    _=core.renderOffline(frames:48000)
    try core.brake(.begin,duration:0.2,deck:.a,generation:a)
    try core.brake(.begin,duration:0.2,deck:.b,generation:b)
    _=core.renderOffline(frames:9600)
    #expect(core.snapshot()?.a.phase == .paused)
    #expect(core.snapshot()?.b.phase == .paused)
    let tail=core.renderOffline(frames:4800)
    #expect(tail.left.contains { abs($0)>1e-6 })
    #expect(tail.left.allSatisfy { $0.isFinite })
}

@Test func vinylBrakePanicAndSourceEndClearTheTemporaryState() throws {
    let (core,generation)=try brakingDeck()
    try core.brake(.begin,deck:.a,generation:generation)
    _=core.renderOffline(frames:100)
    try core.stopAll();core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.braking == false)
    #expect(core.snapshot()?.a.phase == .paused)
    try core.seek(frame:383900,deck:.a,generation:generation)
    try core.play(deck:.a,generation:generation)
    try core.brake(.begin,deck:.a,generation:generation)
    _=core.renderOffline(frames:500)
    #expect(core.snapshot()?.a.phase == .ended)
    #expect(core.snapshot()?.a.braking == false)
}

@Test @MainActor func vinylBrakeWorksWithStreamedAudioAndPreparedResume() async throws {
    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".pcm")
    defer { try? FileManager.default.removeItem(at:url) }
    let samples=(0..<480000).flatMap { frame -> [Float] in
        let x=Float(0.2*sin(2 * .pi * 440*Double(frame)/48000));return [x,x]
    }
    try samples.withUnsafeBytes { try Data($0).write(to:url) }
    let asset=try PCMAsset(streamedFile:url,frames:480000,sampleRate:48000)
    let core=try SampleTransport()
    let generation=try core.reserveLoad(asset,deck:.a,grid:BeatGrid(bpm:120,anchorFrame:0,sampleRate:48000),keylock:true)
    let deadline=Date().addingTimeInterval(5)
    let ticket=try await asset.prepareSources([.init(position:0,keylock:true)],generation:generation,whileWaiting:{
        if Date()>deadline { throw TransportError.sourceCold }
        core.processControlsWhileIdle()
    })
    try core.submitPreparedLoad(generation:generation,preparationTicket:ticket)
    core.processControlsWhileIdle();_=core.acknowledgements()
    try core.play(deck:.a,generation:generation)
    for _ in 0..<20 { _=core.renderOffline(frames:256);try await Task.sleep(for:.milliseconds(1)) }
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    try core.brake(.begin,duration:0.2,deck:.a,generation:generation)
    for _ in 0..<12 { _=core.renderOffline(frames:256);try await Task.sleep(for:.milliseconds(1)) }
    let resume=SourceControl.brake(.resume,1,.a,generation)
    let targets=resume.preparationTargets(snapshot:try #require(core.snapshot()),deck:.a,frames:asset.frames)
    let resumeDeadline=Date().addingTimeInterval(5)
    let resumeTicket=try await asset.prepareSources(targets,generation:generation,whileWaiting:{
        if Date()>resumeDeadline { throw TransportError.sourceCold }
        core.processControlsWhileIdle()
    })
    try core.submit(resume,preparations:[.init(asset:asset,deck:.a,generation:generation,ticket:resumeTicket)])
    for _ in 0..<20 { _=core.renderOffline(frames:256);try await Task.sleep(for:.milliseconds(1)) }
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.a.braking == false)
    #expect(!core.streamingSummary().continuityFailed)
}

@Test func vinylBrakeResumeStillStartsIfTheStopCompletesBeforeConsumption() throws {
    let (core,generation)=try brakingDeck()
    try core.brake(.begin,duration:0.2,deck:.a,generation:generation)
    _=core.renderOffline(frames:9600)
    let position=try #require(core.snapshot()?.a.sourceFrame)
    try core.brake(.resume,deck:.a,generation:generation)
    _=core.renderOffline(frames:256)
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.a.sourceFrame == position+256)
}

@Test func vinylBrakeHandlesDifferentSourceAndOutputSampleRates() throws {
    for (source,output) in [(44100.0,48000.0),(48000,44100),(44100,96000)] {
        let core=try SampleTransport(sampleRate:output)
        let generation=try core.load(brakeTone(rate:source),deck:.a,grid:nil,synced:false)
        try core.play(deck:.a,generation:generation);_=core.renderOffline(frames:1000)
        let start=try #require(core.snapshot()?.a.sourceFrame)
        try core.brake(.begin,duration:0.2,deck:.a,generation:generation)
        _=core.renderOffline(frames:Int(output*0.2))
        let state=try #require(core.snapshot()?.a)
        #expect(state.phase == .paused)
        #expect(abs(state.sourceFrame-start-(source*0.1+0.5*source/output))<0.001)
        #expect(core.renderOffline(frames:256).left.allSatisfy { $0 == 0 })
    }
}

@Test func vinylBrakeCancelsArmedRecoveryAndRejectsRearmingDuringTheStop() throws {
    let (core,generation)=try brakingDeck()
    try core.armRecoveryReplay(deck:.a,generation:generation,dropFrame:0,endFrame:96000)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.recoveryArmed == true)
    try core.brake(.begin,deck:.a,generation:generation)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.braking == true)
    #expect(core.snapshot()?.a.recoveryArmed == false)
    try core.armRecoveryReplay(deck:.a,generation:generation,dropFrame:0,endFrame:96000)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .protectedDeck)
    #expect(core.snapshot()?.a.recoveryArmed == false)
}
