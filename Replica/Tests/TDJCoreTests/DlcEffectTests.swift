import Foundation
import Testing
@testable import TDJCore

private func dlcRig(_ samples: [Float],rate: Double=8000) throws -> (SampleTransport,UInt64) {
    let core=try SampleTransport(sampleRate:rate)
    let g=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:rate),deck:.a,grid:nil,synced:false)
    return (core,g)
}
private func dlcTone(_ effect: PerformanceEffect?,x: Double) throws -> [Float] {
    let samples=(0..<24000).flatMap { frame -> [Float] in
        let value=Float(0.3*sin(2 * .pi*200*Double(frame)/8000))
        return [value,-value]
    }
    let (core,g)=try dlcRig(samples)
    if let effect { try core.setEffect(effect.rawValue,slot:0,x:x,y:1,enabled:true,deck:.a) }
    try core.play(deck:.a,generation:g)
    let audio=core.renderOffline(frames:16000)
    #expect(core.snapshot()?.a.sourceFrame == 16000)
    #expect(zip(audio.left,audio.right).allSatisfy { abs($0+$1)<0.000001 })
    #expect(audio.left.allSatisfy { $0.isFinite })
    return audio.left
}

@Test func transposeIsNeutralAtCentreAndRaisesAnOctaveWithoutChangingTransportTime() throws {
    let dry=try dlcTone(nil,x:0.5)
    let neutral=try dlcTone(.transposeStretch,x:0.5)
    #expect(zip(dry,neutral).allSatisfy { abs($0-$1)<0.000001 })
    let shifted=Array(try dlcTone(.transposeStretch,x:1).dropFirst(8000))
    let crossings=zip(shifted,shifted.dropFirst()).filter { $0<=0 && $1>0 }.count
    #expect(abs(crossings-400)<=2)
}

@Test func reverseGrainCapturesAudioAndReengagementCannotReplayItsOldCapture() throws {
    let samples=(0..<24000).flatMap { frame -> [Float] in
        let value: Float=frame<4000 ? 0.25 : 0
        return [value,-value]
    }
    let (core,g)=try dlcRig(samples)
    try core.setEffect(PerformanceEffect.reverseGrain.rawValue,slot:0,x:0.5,y:1,enabled:true,deck:.a)
    try core.play(deck:.a,generation:g)
    let captured=core.renderOffline(frames:6000)
    #expect(captured.left.suffix(1000).allSatisfy { abs($0-0.125)<0.000001 })
    #expect(core.snapshot()?.a.sourceFrame == 6000)
    try core.play(deck:.a,generation:g)
    let held=core.renderOffline(frames:1000)
    #expect(held.left.allSatisfy { abs($0-0.125)<0.000001 })
    try core.setEffect(PerformanceEffect.reverseGrain.rawValue,slot:0,x:0.5,y:1,enabled:false,deck:.a)
    _=core.renderOffline(frames:100)
    try core.setEffect(PerformanceEffect.reverseGrain.rawValue,slot:0,x:0.5,y:1,enabled:true,deck:.a)
    let recaptured=core.renderOffline(frames:5000)
    #expect(recaptured.left.allSatisfy { abs($0)<0.0000001 })
    #expect(recaptured.right.allSatisfy { abs($0)<0.0000001 })
}

@Test func iceverbHasADiffuseStereoTailAfterPause() throws {
    var samples=[Float](repeating:0,count:32000)
    // Exercise the reverb after the transport's start transition has settled.
    samples[512]=0.4; samples[513] = -0.4
    let (core,g)=try dlcRig(samples)
    try core.setEffect(PerformanceEffect.iceverb.rawValue,slot:0,x:0.5,y:1,enabled:true,deck:.a)
    try core.play(deck:.a,generation:g)
    _=core.renderOffline(frames:1000)
    try core.play(deck:.a,generation:g)
    let tail=core.renderOffline(frames:3000)
    #expect(tail.left.contains { abs($0)>0.00001 })
    #expect(tail.left.allSatisfy { $0.isFinite && abs($0)<1 })
    #expect(tail.right.allSatisfy { $0.isFinite && abs($0)<1 })
    #expect(zip(tail.left,tail.right).contains { abs($0+$1)>0.000001 })
}

@Test func everyDlcHandlesRapidParametersKindChangesAndBypassWithoutInvalidAudio() throws {
    let samples=(0..<16000).flatMap { frame -> [Float] in
        let value=Float(0.2*sin(Double(frame)*0.13))
        return [value,-value]
    }
    let (core,g)=try dlcRig(samples)
    try core.play(deck:.a,generation:g)
    try core.perform(.loop,deck:.a,generation:g,value:0,end:16000)
    for kind in [PerformanceEffect.iceverb,.transposeStretch,.reverseGrain] {
        for step in 0..<30 {
            try core.setEffect(kind.rawValue,slot:0,x:Double(step%11)/10,y:1,enabled:step%7 != 0,deck:.a)
            let audio=core.renderOffline(frames:512)
            #expect(audio.left.allSatisfy { $0.isFinite && abs($0)<2 })
            #expect(audio.right.allSatisfy { $0.isFinite && abs($0)<2 })
            if kind != .iceverb {
                #expect(zip(audio.left.dropFirst(64),audio.right.dropFirst(64)).allSatisfy { abs($0+$1)<0.000001 })
            }
        }
    }
    #expect(PerformanceEffect.supportedCount == 11)
    #expect(PerformanceEffect.allCases.count == 11)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func dlcLiveProcessorsCannotReplayPreBypassAudio() throws {
    for kind in [PerformanceEffect.iceverb,.transposeStretch] {
        let samples=(0..<16000).flatMap { frame -> [Float] in
            let value: Float=frame<4000 ? 0.25 : 0
            return [value,-value]
        }
        let (core,g)=try dlcRig(samples)
        try core.setEffect(kind.rawValue,slot:0,x:0.8,y:1,enabled:true,deck:.a)
        try core.play(deck:.a,generation:g)
        _=core.renderOffline(frames:3500)
        try core.setEffect(kind.rawValue,slot:0,x:0.8,y:1,enabled:false,deck:.a)
        _=core.renderOffline(frames:1500)
        try core.setEffect(kind.rawValue,slot:0,x:0.8,y:1,enabled:true,deck:.a)
        let audio=core.renderOffline(frames:5000)
        #expect(audio.left.allSatisfy { abs($0)<0.0000001 })
        #expect(audio.right.allSatisfy { abs($0)<0.0000001 })
    }
}
