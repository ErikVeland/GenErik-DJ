import AVFoundation
import Foundation
import Testing
@testable import TDJCore

@Test func recordingIncludesMasterEffectsAndTailAfterDeckPause() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let core=try SampleTransport()
    let samples=(0..<24000).flatMap { frame -> [Float] in
        let sample=Float(sin(Double(frame)*2 * .pi * 440/48000))*0.2
        return [sample,-sample]
    }
    let generation=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:48000),deck:.a,grid:nil,synced:false)
    try core.setEffect(0,slot:0,x:0,y:0.7,enabled:true,deck:.a)
    let recorder=try SetRecorder(directory:root,sampleRate:48000,buffer:core.recording)
    try core.play(deck:.a,generation:generation)
    let playing=core.renderOffline(frames:7000)
    try core.play(deck:.a,generation:generation)
    let tail=core.renderOffline(frames:1500)
    #expect(core.snapshot()?.a.phase == .paused)
    #expect(tail.left.contains { abs($0)>0.0001 })
    let file=try AVAudioFile(forReading:await recorder.finish())
    #expect(file.length == 8500)
    let buffer=try #require(AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:8500))
    try file.read(into:buffer)
    let expected=[playing.left+tail.left,playing.right+tail.right]
    let channels=try #require(buffer.floatChannelData)
    for channel in 0..<2 {
        let error=expected[channel].indices.map { abs(channels[channel][$0]-expected[channel][$0]) }.max()!
        #expect(error < 0.000001)
    }
}
