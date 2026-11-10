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

@Test func s2MK3EjectRetiresOnlyTheStoppedDeck() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.0, count: 64_000), sampleRate: 8000)
    let a = try core.load(asset, deck: .a, grid: nil)
    let b = try core.load(asset, deck: .b, grid: nil)
    try core.play(deck: .b, generation: b)
    core.processControlsWhileIdle()
    _ = core.acknowledgements()
    try core.eject(deck: .a, generation: a)
    try core.eject(deck: .b, generation: b)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().compactMap(\.error) == [.protectedDeck])
    #expect(core.asset(generation: a) == nil)
    #expect(core.snapshot()?.a.phase == .empty)
    #expect(core.snapshot()?.b.phase == .playing)
    #expect(core.asset(generation: b) != nil)
}

@Test func s2MK3RollReturnsToTheContinuingCursorWithFluxOff() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.0, count: 64_000), sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let generation = try core.load(asset, deck: .a, grid: grid, synced: false)
    try core.play(deck: .a, generation: generation)
    _ = core.renderBusesOffline(frames: 1000)
    try core.perform(.loopRoll, deck: .a, generation: generation, value: 0, end: 4000)
    _ = core.renderBusesOffline(frames: 4500)
    #expect(core.snapshot()?.a.sourceFrame == 1500)
    #expect(core.snapshot()?.a.fluxEnabled == false)
    try core.perform(.loopRoll, deck: .a, generation: generation, enabled: false)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?.a.sourceFrame == 5500)
    #expect(core.snapshot()?.a.loopEnabled == false)
    #expect(core.snapshot()?.a.fluxEnabled == false)
}

@Test func s2MK3GridTickFollowsTheDraftAndStaysInCue() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.0, count: 64_000), sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let generation = try core.load(asset, deck: .a, grid: grid, synced: false)
    try core.setMixer(.cue, value: 1, deck: .a)
    try core.play(deck: .a, generation: generation)
    try core.setGridMetronome(offset: 1000, deck: .a, generation: generation)
    let audio = core.renderBusesOffline(frames: 1200)
    #expect(audio.left.allSatisfy { $0 == 0 })
    #expect(audio.cueLeft.prefix(1000).allSatisfy { $0 == 0 })
    #expect(audio.cueLeft.dropFirst(1000).contains { abs($0) > 0.01 })
    try core.setGridMetronome(offset: nil, deck: .a, generation: generation)
    #expect(core.renderBusesOffline(frames: 4500).cueLeft.allSatisfy { $0 == 0 })
    try core.setMixer(.cue, value: 0, deck: .a)
    try core.setGridMetronome(offset: 0, deck: .a, generation: generation)
    #expect(core.renderBusesOffline(frames: 4500).cueLeft.allSatisfy { $0 == 0 })
}

@Test func s3MasterMeterReadsFinalStereoMasterInsteadOfCue() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let asset = try PCMAsset(interleavedStereo: Array(repeating: [Float(0.25), 0.75], count: 4000).flatMap { $0 }, sampleRate: 8000)
    let generation = try core.load(asset, deck: .a, grid: nil)
    try core.setMixer(.cue, value: 1, deck: .a)
    try core.setMixer(.master, value: 0.5)
    core.setMasterMeterEnabled(true)
    _ = core.renderBusesOffline(frames: 1024)
    try core.play(deck: .a, generation: generation)
    _ = core.renderBusesOffline(frames: 1024)
    #expect(abs(core.masterMeter.left - 0.125) < 0.001)
    #expect(abs(core.masterMeter.right - 0.375) < 0.001)
    core.setMasterMeterEnabled(false)
    #expect(core.masterMeter.left == 0)
}

@Test func s3PreviewFeedsOnlyHeadphonesAndRejectsOldProducer() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    core.setPreviewGeneration(1)
    try core.setMixer(.monitor, value: 1)
    let samples: [Float] = Array(repeating: [Float(0.25), Float(0.5)], count: 512).flatMap { $0 }
    #expect(core.pushPreview(samples, frames: 512, sampleRate: 8000, generation: 1))
    let playing = core.renderBusesOffline(frames: 256)
    #expect(playing.left.allSatisfy { $0 == 0 } && playing.right.allSatisfy { $0 == 0 })
    #expect(playing.cueRight.last == 0.25)
    core.setPreviewGeneration(0)
    #expect(!core.pushPreview(samples, frames: 512, sampleRate: 8000, generation: 1))
    #expect(core.renderBusesOffline(frames: 256).cueRight.last == 0)
}

@Test func s3ExternalInputPreservesStereoAndCueIgnoresTheFader() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let owner = core.nativeAudioRenderOwnership(metrics: nil)
    let left = [Float](repeating: 0.25, count: 1024)
    let right = [Float](repeating: 0.75, count: 1024)
    core.setExternalInputMix(level: 0, cue: true)
    try core.setMixer(.monitor, value: 1)
    core.setMicrophoneEnabled(true)
    left.withUnsafeBufferPointer { l in
        right.withUnsafeBufferPointer { r in
            tdj_external_input_push(owner.engineHandle, l.baseAddress, r.baseAddress, 1024, 1, 8000)
        }
    }
    let cue = core.renderBusesOffline(frames: 256)
    #expect(cue.left.last == 0 && cue.right.last == 0)
    #expect(cue.cueLeft.last == 0.25 && cue.cueRight.last == 0.75)
    core.setExternalInputMix(level: 0.5, cue: false)
    let main = core.renderBusesOffline(frames: 256)
    #expect(main.left.last == 0.125 && main.right.last == 0.375)
    #expect(main.cueLeft.last == 0 && main.cueRight.last == 0)
}
