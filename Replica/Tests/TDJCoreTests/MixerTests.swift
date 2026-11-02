import AVFoundation
import Foundation
import Testing
@testable import TDJCore

private func mixerPair() throws -> SampleTransport {
    let core = try SampleTransport()
    let a = try core.load(PCMAsset(interleavedStereo: Array(repeating: [Float(0.4), 0], count: 96000).flatMap { $0 }, sampleRate: 48000), deck: .a, grid: nil, synced: false)
    let b = try core.load(PCMAsset(interleavedStereo: Array(repeating: [Float(0), 0.8], count: 96000).flatMap { $0 }, sampleRate: 48000), deck: .b, grid: nil, synced: false)
    try core.play(deck: .a, generation: a); try core.play(deck: .b, generation: b)
    return core
}

@Test func mixerCrossfaderEndpointsAndVolumeDoNotStopTransport() throws {
    let core=try mixerPair()
    try core.setMixer(.crossfader,value:0)
    let first=core.renderOffline(frames:1024)
    #expect(abs(first.left.last! - 0.2)<1e-6)
    #expect(first.right.last! == 0)
    #expect(core.snapshot()?.b.sourceFrame == 1024)
    try core.setMixer(.crossfader,value:1)
    let next=core.renderOffline(frames:1024)
    #expect(next.left.last! == 0)
    #expect(abs(next.right.last! - 0.4)<1e-6)
    try core.setMixer(.volume,value:0,deck:.b)
    let muted=core.renderOffline(frames:1024)
    #expect(muted.left.last! == 0 && muted.right.last! == 0)
    #expect(core.snapshot()?.b.phase == .playing)
}

@Test func headphoneCueIsIndependentOfFadersAndNeverEntersRecording() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let core=try mixerPair()
    try core.setMixer(.crossfader,value:0)
    try core.setMixer(.volume,value:0,deck:.b)
    try core.setMixer(.cue,value:1,deck:.b)
    _=core.renderOffline(frames:512)
    let recorder=try SetRecorder(directory:root,sampleRate:48000,buffer:core.recording)
    let audio=core.renderBusesOffline(frames:1024)
    #expect(audio.left.allSatisfy { abs($0-0.2)<1e-6 })
    #expect(audio.right.allSatisfy { $0 == 0 })
    #expect(audio.cueLeft.allSatisfy { $0 == 0 })
    #expect(audio.cueRight.allSatisfy { abs($0-0.4)<1e-6 })
    let file=try AVAudioFile(forReading:await recorder.finish())
    let buffer=try #require(AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:1024))
    try file.read(into:buffer)
    #expect(UnsafeBufferPointer(start:buffer.floatChannelData![1],count:1024).allSatisfy { $0 == 0 })
    try core.setMixer(.cueBlend,value:1)
    let masterCue=core.renderBusesOffline(frames:1024)
    #expect(abs(masterCue.cueLeft.last! - 0.1)<1e-6)
    #expect(masterCue.cueRight.last! == 0)
}

@Test func mixerChangesRampAndInvalidValuesLeaveTargetsUnchanged() throws {
    let core=try mixerPair()
    _=core.renderOffline(frames:512); _=core.acknowledgements()
    try core.setMixer(.master,value:0)
    let audio=core.renderOffline(frames:512)
    #expect(audio.left.first! > 0.19)
    #expect(audio.left[239] == 0)
    for i in 1..<240 { #expect(abs(audio.left[i]-audio.left[i-1])<0.001) }
    for value in [Double.nan, .infinity, -1, 2] { try core.setMixer(.crossfader,value:value) }
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.crossfader == 0.5)
    #expect(core.acknowledgements().filter { $0.error == .invalid }.count == 4)
}

@Test func neutralEQIsTransparentAndEQResetDoesNotResetVolume() throws {
    let core=try mixerPair()
    _=core.renderOffline(frames:96)
    let audio=core.renderOffline(frames:1024)
    #expect(audio.left.allSatisfy { abs($0-0.2)<1e-6 })
    try core.setMixer(.volume,value:0.3)
    for band in [MixerParameter.low,.mid,.high] { try core.setMixer(band,value:0) }
    let killed=core.renderOffline(frames:1024)
    #expect(abs(killed.left.last!)<1e-6)
    for band in [MixerParameter.low,.mid,.high] { try core.setMixer(band,value:1) }
    let restored=core.renderOffline(frames:1024)
    #expect(abs(restored.left.last!-0.06)<1e-6)
    #expect(core.snapshot()?.a.mixer.volume == 0.3)
}

@Test func filterCutsFrequencyAndRetainsResonanceWhenBypassed() throws {
    let core=try SampleTransport()
    let samples=(0..<48000).flatMap { i -> [Float] in
        let x=Float(sin(2 * .pi * 8000 * Double(i)/48000))*0.3
        return [x,-x]
    }
    let a=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:48000),deck:.a,grid:nil,synced:false)
    try core.play(deck:.a,generation:a)
    try core.setMixer(.filterX,value:-0.7)
    try core.setMixer(.filterY,value:0.3)
    try core.setMixer(.filterEnabled,value:1)
    let filtered=core.renderOffline(frames:12000)
    #expect(filtered.left.suffix(6000).map { abs($0) }.max()! < 0.001)
    try core.setMixer(.filterEnabled,value:0)
    let dry=core.renderOffline(frames:12000)
    #expect(dry.left.suffix(6000).map { abs($0) }.max()! > 0.12)
    #expect(core.snapshot()?.a.mixer.filterY == 0.3)
    for i in dry.left.indices { #expect(abs(dry.left[i]+dry.right[i])<1e-6) }
}

@Test func onlyAudibleMasterOverlapCountsAsAPair() throws {
    let core=try mixerPair()
    try core.setMixer(.crossfader,value:0)
    // Let smoothing finish before loading again to reset the pair generation.
    _=core.renderOffline(frames:512)
    try core.stopAll(); core.processControlsWhileIdle()
    let replacement=try core.load(PCMAsset(interleavedStereo:Array(repeating:[Float(0),0.8],count:96000).flatMap { $0 },sampleRate:48000),deck:.b,grid:nil,synced:false)
    let a=try #require(core.snapshot()?.a.generation)
    try core.play(deck:.a,generation:a); try core.play(deck:.b,generation:replacement)
    try core.setMixer(.cue,value:1,deck:.b)
    _=core.renderBusesOffline(frames:1024)
    #expect(core.snapshot()?.pairedFrames == 0)
    try core.setMixer(.crossfader,value:0.5)
    _=core.renderOffline(frames:1024)
    #expect(try #require(core.snapshot()?.pairedFrames)>0)
}

@Test func rapidMixerAndResonantFilterChangesRemainFinite() throws {
    let core=try mixerPair()
    for i in 0..<256 {
        try core.setMixer(.filterEnabled,value:1)
        try core.setMixer(.filterX,value:Double(i%21)/10-1)
        try core.setMixer(.filterY,value:Double(i%11)/10)
        try core.setMixer(.crossfader,value:Double(i%7)/6)
        let block=core.renderBusesOffline(frames:128)
        #expect(block.left.allSatisfy { $0.isFinite && abs($0)<10 })
        #expect(block.cueLeft.allSatisfy { $0.isFinite })
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    }
}
