import Foundation
import Testing
@testable import TDJCore

private func effectTone(_ kind: PerformanceEffect?, frequency: Double = 440, x: Double = 0.5) throws -> [Float] {
    let rate=48000.0
    let samples=(0..<20000).flatMap { frame -> [Float] in
        let value=Float(0.4*sin(2 * .pi*frequency*Double(frame)/rate))
        return [value,-value]
    }
    let core=try SampleTransport(sampleRate:rate)
    let generation=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:rate),deck:.a,grid:nil,synced:false)
    if let kind { try core.setEffect(kind.rawValue,slot:0,x:x,y:1,enabled:true,deck:.a) }
    try core.play(deck:.a,generation:generation)
    let audio=core.renderOffline(frames:12000)
    #expect(audio.left.allSatisfy { $0.isFinite })
    #expect(zip(audio.left,audio.right).allSatisfy { abs($0+$1)<0.000001 })
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    return Array(audio.left.dropFirst(2000))
}
private func effectRMS(_ samples: [Float]) -> Double {
    sqrt(samples.reduce(0) { $0+Double($1)*Double($1) }/Double(samples.count))
}

@Test func digitalLoFiReducesResolutionAndSampleRateWithoutBreakingStereo() throws {
    let dry=try effectTone(nil)
    let full=try effectTone(.digitalLoFi,x:0)
    #expect(zip(dry,full).allSatisfy { abs($0-$1)<0.000001 })
    let reduced=try effectTone(.digitalLoFi,x:1)
    let changes=zip(reduced,reduced.dropFirst()).filter { abs($0-$1)>0.000001 }.count
    #expect(changes>0 && changes<30)
    #expect(Set(reduced).count<=5)
}

@Test func dedicatedEffectFiltersAttenuateOppositeFrequencyBands() throws {
    for (frequency,attenuated,passed) in [(100.0,PerformanceEffect.highPass,PerformanceEffect.lowPass),
                                         (3200.0,PerformanceEffect.lowPass,PerformanceEffect.highPass)] {
        let dry=effectRMS(try effectTone(nil,frequency:frequency))
        let cut=effectRMS(try effectTone(attenuated,frequency:frequency))
        let kept=effectRMS(try effectTone(passed,frequency:frequency))
        #expect(cut/dry<0.1)
        #expect(kept/dry>0.85)
    }
}

@Test func baseEffectCatalogAndRendererAcceptTheSameKinds() throws {
    #expect(PerformanceEffect.allCases.count == PerformanceEffect.supportedCount)
    let core=try SampleTransport(sampleRate:48000)
    for effect in PerformanceEffect.allCases {
        try core.setEffect(effect.rawValue,slot:0,x:0.5,y:0.5,enabled:true,deck:.a)
        _=core.renderOffline(frames:512)
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    }
    #expect(throws:TransportError.self) {
        try core.setEffect(PerformanceEffect.supportedCount,slot:0,x:0.5,y:0.5,enabled:true,deck:.a)
    }
}

@Test func addedBaseEffectsStayFiniteDuringRapidSweepsAndSwitches() throws {
    let core=try SampleTransport(sampleRate:48000)
    let samples=(0..<48000).flatMap { frame -> [Float] in
        let sample=Float(0.35*sin(Double(frame)*0.3))
        return [sample,-sample]
    }
    let generation=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:48000),deck:.a,grid:nil,synced:false)
    try core.play(deck:.a,generation:generation)
    for step in 0..<100 {
        let kind=[PerformanceEffect.digitalLoFi,.highPass,.lowPass][step%3]
        try core.setEffect(kind.rawValue,slot:0,x:Double(step%11)/10,y:1,enabled:true,deck:.a)
        let audio=core.renderOffline(frames:256)
        #expect(audio.left.allSatisfy { $0.isFinite && abs($0)<1 })
        #expect(zip(audio.left,audio.right).allSatisfy { abs($0+$1)<0.000001 })
    }
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func addedBaseEffectsCannotReplayHeldAudioAfterBypass() throws {
    for kind in [PerformanceEffect.digitalLoFi,.highPass,.lowPass] {
        let core=try SampleTransport(sampleRate:48000)
        let samples=(0..<12000).flatMap { frame -> [Float] in
            let value: Float=frame<4000 ? 0.35 : 0
            return [value,-value]
        }
        let generation=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:48000),deck:.a,grid:nil,synced:false)
        try core.setEffect(kind.rawValue,slot:0,x:0.5,y:1,enabled:true,deck:.a)
        try core.play(deck:.a,generation:generation)
        _=core.renderOffline(frames:3000)
        try core.setEffect(kind.rawValue,slot:0,x:0.5,y:1,enabled:false,deck:.a)
        _=core.renderOffline(frames:2000)
        try core.setEffect(kind.rawValue,slot:0,x:0.5,y:1,enabled:true,deck:.a)
        let audio=core.renderOffline(frames:1024)
        #expect(audio.left.allSatisfy { abs($0)<0.00000001 })
        #expect(audio.right.allSatisfy { abs($0)<0.00000001 })
    }
}

@Test func freeDelayDoesNotChangeWithMasterTempo() throws {
    func output(bpm: Double, synced: Bool) throws -> [Float] {
        let rate=8000.0
        let samples=(0..<16000).flatMap { frame -> [Float] in
            let value: Float = frame == 800 ? 0.8 : 0
            return [value,value]
        }
        let core=try SampleTransport(sampleRate:rate)
        let generation=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:rate),deck:.a,grid:nil,synced:false)
        try core.setMasterBPM(bpm)
        try core.setEffect(0,slot:0,x:0.5,y:1,enabled:true,deck:.a,synced:synced)
        try core.play(deck:.a,generation:generation)
        return core.renderOffline(frames:12000).left
    }
    let free120=try output(bpm:120,synced:false)
    let free150=try output(bpm:150,synced:false)
    #expect(free120 == free150)
    #expect(try output(bpm:120,synced:true) != output(bpm:150,synced:true))
}

@Test func syncedDelayPreservesFourBeatsAtSlowTempo() throws {
    let rate=8000.0
    let samples=(0..<76000).flatMap { frame -> [Float] in
        let value: Float = frame == 800 ? 0.8 : 0
        return [value,value]
    }
    let core=try SampleTransport(sampleRate:rate)
    let generation=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:rate),deck:.a,grid:nil,synced:false)
    try core.setMasterBPM(30)
    try core.setEffect(0,slot:0,x:1,y:1,enabled:true,deck:.a)
    try core.play(deck:.a,generation:generation)
    let output=core.renderOffline(frames:70000).left
    #expect(abs(output[64800]) > 0.01)
    #expect(abs(output[16801]) < 0.000001)
}
