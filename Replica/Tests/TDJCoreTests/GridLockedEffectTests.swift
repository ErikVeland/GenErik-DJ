import Foundation
import Testing
@testable import TDJCore

// 120 BPM at 8 kHz: one beat is 4000 frames. Ungridded decks follow the master clock.
private func gridRender(_ samples: [Float], effect: PerformanceEffect?, x: Double, frames: Int) throws -> [Float] {
    let core=try SampleTransport(sampleRate:8000)
    let generation=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:8000),deck:.a,grid:nil,synced:false)
    try core.setMasterBPM(120)
    if let effect { try core.setEffect(effect.rawValue,slot:0,x:x,y:1,enabled:true,deck:.a) }
    try core.play(deck:.a,generation:generation)
    let audio=core.renderOffline(frames:frames)
    #expect(audio.left.allSatisfy { $0.isFinite })
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    return audio.left
}
private func noise(_ count: Int, level: Float = 0.2) -> [Float] {
    var state: UInt32=0x1234_5678
    return (0..<count).flatMap { _ -> [Float] in
        state=state &* 1_664_525 &+ 1_013_904_223
        let value=(Float(state>>8)/Float(1<<24)*2-1)*level
        return [value,value]
    }
}
private func energy(_ samples: ArraySlice<Float>) -> Double { samples.reduce(0) { $0+Double($1)*Double($1) } }

@Test func flangerIsClearlyAudibleAndAddsEnergyOnTopOfTheDryTrack() throws {
    let input=noise(24000)
    let dry=try gridRender(input,effect:nil,x:0,frames:16000)
    let flanged=try gridRender(input,effect:.flanger,x:0,frames:16000)
    let span=2000..<16000
    #expect(energy(flanged[span]) > energy(dry[span])*1.2)
    let difference=zip(flanged[span],dry[span]).map { Double($0-$1)*Double($0-$1) }.reduce(0,+)
    #expect(difference > energy(dry[span])*0.2)
}

@Test func beatmasherRepeatsTheSliceRecordedFromTheNextGridLine() throws {
    let input=noise(24000)
    let dry=try gridRender(input,effect:nil,x:0,frames:6000)
    // x=0 selects 1/8 beat (500 frames). The slice starts on the line at frame 500.
    let mashed=try gridRender(input,effect:.beatmasher,x:0,frames:6000)
    #expect(zip(mashed[100..<1000],dry[100..<1000]).allSatisfy { abs($0-$1)<0.000001 })
    for repeatStart in [1000,1500,4500] {
        let window=(repeatStart+100)..<(repeatStart+500)
        #expect(window.allSatisfy { abs(mashed[$0]-dry[$0-repeatStart+500])<0.0001 })
    }
    #expect(energy(mashed[1100..<6000]) > energy(dry[1100..<6000])*0.5)
}

@Test func beatmasherEngagedLaterRepeatsLiveAudioRatherThanSilence() throws {
    let input=noise(24000)
    let core=try SampleTransport(sampleRate:8000)
    let generation=try core.load(PCMAsset(interleavedStereo:input,sampleRate:8000),deck:.a,grid:nil,synced:false)
    try core.setMasterBPM(120)
    try core.setEffect(PerformanceEffect.beatmasher.rawValue,slot:0,x:0,y:1,enabled:false,deck:.a)
    try core.play(deck:.a,generation:generation)
    _=core.renderOffline(frames:4250)
    try core.setEffect(PerformanceEffect.beatmasher.rawValue,slot:0,x:0,y:1,enabled:true,deck:.a)
    let audio=core.renderOffline(frames:2000).left
    // Waits for the line at frame 4500, records 500 frames, then repeats them.
    // Output is half scale: uniform noise at 0.1 has a mean square of 0.01/3.
    #expect(energy(audio[1300..<2000]) > 0.8*700*0.01/3)
}

@Test func gaterOpensForTheFirstHalfOfEachGridDivision() throws {
    let input=(0..<24000).flatMap { _ -> [Float] in [0.4,0.4] }
    let dry=try gridRender(input,effect:nil,x:0,frames:8000)
    // x=1 selects 1/2 beat (2000 frames): open for 1000 frames, closed for 1000.
    let gated=try gridRender(input,effect:.gater,x:1,frames:8000)
    for start in stride(from:0,to:8000,by:2000) {
        #expect(((start+200)..<(start+900)).allSatisfy { abs(gated[$0]-dry[$0])<0.000001 })
        #expect(((start+1100)..<(start+1900)).allSatisfy { abs(gated[$0])<0.000001 })
    }
    // 64-sample edges, never a hard click.
    #expect(abs(gated[1032]-dry[1032]*0.5)<0.005)
}

@Test func gaterDivisionsFollowTheFiveGridSteps() throws {
    let input=(0..<24000).flatMap { _ -> [Float] in [0.4,0.4] }
    for (x,frames) in [(0.0,125),(0.25,250),(0.5,500),(0.75,1000),(1.0,2000)] {
        let gated=try gridRender(input,effect:.gater,x:x,frames:7000)
        let window=2000..<(2000+frames)
        // The pattern repeats every division and is open, then closing, within it.
        #expect(window.allSatisfy { abs(gated[$0]-gated[$0+frames])<0.000001 })
        // Most open just before the half-division edge, most closed just before the next line.
        #expect(gated[2000+frames/2-1] > 0.15)
        #expect(gated[2000+frames-1] < gated[2000+frames/2-1]*0.05)
    }
}
