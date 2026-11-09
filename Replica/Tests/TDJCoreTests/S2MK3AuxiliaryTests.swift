import AVFoundation
import CTDJTransport
import Testing

@testable import TDJCore

@Test func s2MK3SampleBankPlaysAndReleasesWithoutChangingDecks() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let asset = try PCMAsset(
        interleavedStereo: Array(repeating: [Float(0.5), 0.25], count: 1024).flatMap { $0 }, sampleRate: 8000)
    let generation = try core.setPadAsset(asset, slot: 15)
    try core.playPad(15, generation: generation, enabled: true)
    let first = core.renderBusesOffline(frames: 64)
    #expect(core.playingPads == 1 << 15)
    #expect(first.left[0] == 0)
    #expect(abs(first.left[63] - 0.175) < 0.0001)
    #expect(abs(first.right[63] - 0.0875) < 0.0001)
    #expect(first.cueLeft.allSatisfy { $0 == 0 })
    #expect(core.snapshot()?.a.phase == .empty)
    try core.playPad(15, generation: generation, enabled: false)
    let tail = core.renderBusesOffline(frames: 64)
    #expect(tail.left[0] == first.left[63])
    #expect(tail.left[63] == 0)
    #expect(core.playingPads == 0)
    _ = try core.setPadAsset(nil, slot: 15)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(core.asset(generation: generation) == nil)
}

@Test func s2MK3MicrophoneUsesMasterAndRecordingWithRateConversion() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let owner = core.nativeAudioRenderOwnership(metrics: nil)
    let input = Array(repeating: Float(0.25), count: 1024)
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 2))
    let recorded = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256))
    core.recording.start()
    core.setMicrophoneEnabled(true)
    input.withUnsafeBufferPointer { tdj_microphone_push(owner.engineHandle, $0.baseAddress, 1024, 1, 16000) }
    let audio = core.renderBusesOffline(frames: 256)
    #expect(audio.left[255] == 0.25 && audio.right[255] == 0.25)
    #expect(audio.cueLeft.allSatisfy { $0 == 0 } && audio.cueRight.allSatisfy { $0 == 0 })
    #expect(core.recording.read(into: recorded) == 256)
    #expect(recorded.floatChannelData?[0][255] == 0.25)
    core.setMicrophoneEnabled(false)
    let muted = core.renderBusesOffline(frames: 256)
    #expect(muted.left.last == 0)
    core.setMicrophoneEnabled(true)
    #expect(core.renderBusesOffline(frames: 256).left.allSatisfy { $0 == 0 })
}
