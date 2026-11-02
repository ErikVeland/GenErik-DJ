import Foundation
import Testing
@testable import TDJCore

private func tonalAsset(rate: Double = 48000, seconds: Double = 4, left: Double = 440, right: Double = 660, polarity: Double = 1) throws -> PCMAsset {
    var data = [Float](repeating: 0, count: Int(rate*seconds)*2)
    for i in 0..<(data.count/2) {
        data[i*2] = Float(0.2*sin(2 * .pi * left*Double(i)/rate))
        data[i*2+1] = Float(polarity*0.2*sin(2 * .pi * right*Double(i)/rate))
    }
    return try PCMAsset(interleavedStereo: data, sampleRate: rate)
}

private func measuredFrequency(_ samples: ArraySlice<Float>, rate: Double) -> Double {
    var crossings: [Double] = []
    for i in samples.indices.dropFirst() where samples[i-1] <= 0 && samples[i] > 0 {
        crossings.append(Double(i-1) + Double(-samples[i-1])/Double(samples[i]-samples[i-1]))
    }
    guard crossings.count > 2 else { return 0 }
    return Double(crossings.count-1)*rate/(crossings.last!-crossings.first!)
}

private func preparedTone(speed: Double, keylock: Bool, rate: Double = 48000, sourceRate: Double = 48000) throws -> (SampleTransport, UInt64) {
    let core = try SampleTransport(sampleRate: rate)
    let generation = try core.load(tonalAsset(rate: sourceRate), deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: sourceRate), keylock: keylock)
    try core.setMasterBPM(120*speed)
    try core.play(deck: .a, generation: generation)
    return (core, generation)
}

@Test func keylockPreservesPitchWhileUnlockedPlaybackChangesIt() throws {
    for speed in [0.8, 1.075, 1.25] {
        for enabled in [false, true] {
            let (core, _) = try preparedTone(speed: speed, keylock: enabled)
            let audio = core.renderOffline(frames: 96000)
            for (samples, frequency) in [(audio.left,440.0),(audio.right,660.0)] {
                let measured = measuredFrequency(samples[24000..<90000], rate: 48000)
                let expected = frequency*(enabled ? 1 : speed)
                #expect(abs(1200*log2(measured/expected)) < 3)
                #expect(samples.allSatisfy { $0.isFinite })
            }
            #expect(abs(try #require(core.snapshot()?.a.sourceFrame)-96000*speed) < 0.001)
        }
    }
}

@Test func keylockUsesNativePitchAcrossSourceAndOutputSampleRates() throws {
    for (source, output) in [(44100.0,48000.0),(48000,44100),(44100,96000)] {
        let (core, _) = try preparedTone(speed: 1.2, keylock: true, rate: output, sourceRate: source)
        let audio = core.renderOffline(frames: Int(output*1.5))
        let frequency = measuredFrequency(audio.left[Int(output*0.5)..<Int(output*1.4)], rate: output)
        #expect(abs(1200*log2(frequency/440)) < 3)
        #expect(abs(try #require(core.snapshot()?.a.sourceFrame)-source*1.8) < 0.001)
    }
}

@Test func unityKeylockBypassIsSampleIdentical() throws {
    let (locked, _) = try preparedTone(speed: 1, keylock: true)
    let (unlocked, _) = try preparedTone(speed: 1, keylock: false)
    let a = locked.renderOffline(frames: 10001), b = unlocked.renderOffline(frames: 10001)
    #expect(a.left == b.left)
    #expect(a.right == b.right)
}

@Test func keylockKeepsStereoPolarityAndChannelIsolation() throws {
    let core = try SampleTransport()
    let generation = try core.load(tonalAsset(left: 440, right: 440, polarity: -1), deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000), keylock: true)
    try core.setMasterBPM(150); try core.play(deck: .a, generation: generation)
    let audio = core.renderOffline(frames: 48000)
    let maximumResidual = zip(audio.left,audio.right).map { abs($0+$1) }.max() ?? 0
    #expect(maximumResidual < 1e-5)
    #expect(audio.left[24000...].contains { abs($0) > 0.05 })
}

@Test func lockedQueuedPlayHasNoAddedSchedulerDelay() throws {
    let core = try SampleTransport()
    let referenceOnly = try SampleTransport()
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    let reference = try tonalAsset(left: 440, right: 0)
    let a = try core.load(reference, deck: .a, grid: grid, keylock: true)
    let referenceA = try referenceOnly.load(reference, deck: .a, grid: grid, keylock: true)
    let b = try core.load(tonalAsset(left: 0, right: 660), deck: .b, grid: grid, keylock: true)
    try core.setMasterBPM(150); try core.play(deck: .a, generation: a)
    try referenceOnly.setMasterBPM(150); try referenceOnly.play(deck: .a, generation: referenceA)
    _ = core.renderOffline(frames: 30000)
    _ = referenceOnly.renderOffline(frames: 30000)
    try core.play(deck: .b, generation: b)
    let wait = core.renderOffline(frames: 46800)
    let baseline = referenceOnly.renderOffline(frames: 46800)
    #expect(wait.left == baseline.left)
    #expect(wait.right == baseline.right)
    #expect(core.snapshot()?.b.sourceFrame == 0)
    let start = core.renderOffline(frames: 12000)
    #expect(core.snapshot()?.b.lastStartOutputFrame == 76800)
    #expect(start.right.prefix(240).contains { abs($0) > 1e-4 })
    #expect(abs(measuredFrequency(start.right[4800...], rate: 48000)-660) < 1)
}

@Test func keylockBlockPartitionDoesNotMoveOrChangeAudio() throws {
    let (reference, _) = try preparedTone(speed: 1.075, keylock: true)
    let expected = reference.renderOffline(frames: 24000)
    for block in [7, 127, 256, 4096] {
        let (core, _) = try preparedTone(speed: 1.075, keylock: true)
        var left: [Float] = [], right: [Float] = []
        while left.count < 24000 {
            let next = core.renderOffline(frames: min(block, 24000-left.count))
            left += next.left; right += next.right
        }
        #expect(left == expected.left)
        #expect(right == expected.right)
    }
}

@Test func keylockToggleDoesNotChangeSyncPositionOrPlaybackState() throws {
    let (core, generation) = try preparedTone(speed: 1.1, keylock: true)
    _ = core.renderOffline(frames: 24000)
    let before = try #require(core.snapshot())
    try core.setKeylock(false, deck: .a, generation: generation); core.processControlsWhileIdle()
    let off = try #require(core.snapshot())
    #expect(off.a.keylock == false)
    #expect(off.a.synced == before.a.synced)
    #expect(off.a.sourceFrame == before.a.sourceFrame)
    #expect(off.masterBeat == before.masterBeat)
    #expect(off.a.phase == .playing)
    _ = core.renderOffline(frames: 24000)
    try core.setKeylock(true, deck: .a, generation: generation)
    let on = core.renderOffline(frames: 48000)
    #expect(abs(measuredFrequency(on.left[12000...], rate: 48000)-440) < 1)
    #expect(core.snapshot()?.a.keylock == true)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func tempoAutomationRetainsPitchAndTheSourceTimeline() throws {
    let (core, _) = try preparedTone(speed: 0.9, keylock: true)
    _ = core.renderOffline(frames: 24000)
    let beat = core.snapshot()?.masterBeat
    try core.setMasterBPM(150); core.processControlsWhileIdle()
    #expect(core.snapshot()?.masterBeat == beat)
    let audio = core.renderOffline(frames: 48000)
    #expect(abs(measuredFrequency(audio.left[12000...], rate: 48000)-440) < 1)
    let sourceFrame = try #require(core.snapshot()?.a.sourceFrame)
    let expectedFrame = 24000.0*0.9+48000.0*1.25
    #expect(abs(sourceFrame - expectedFrame) < 0.001)
    #expect(audio.left.allSatisfy { $0.isFinite && abs($0) <= 0.3 })
}

@Test func pendingAndStaleKeylockActionsCannotChangeTheWrongSource() throws {
    let (core, a) = try preparedTone(speed: 1.1, keylock: true)
    let b = try core.load(tonalAsset(), deck: .b, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000), keylock: true)
    _ = core.renderOffline(frames: 10000)
    try core.play(deck: .b, generation: b); core.processControlsWhileIdle(); _ = core.acknowledgements()
    try core.setKeylock(false, deck: .b, generation: b)
    try core.setKeylock(false, deck: .a, generation: a+100)
    core.processControlsWhileIdle()
    #expect(core.acknowledgements().map(\.error) == [.unresolved, .stale])
    #expect(core.snapshot()?.b.phase == .queued)
    #expect(core.snapshot()?.a.keylock == true)
    #expect(core.snapshot()?.b.keylock == true)
}

@Test func lockedEndOfFileStopsWithoutReadingPastTheSource() throws {
    let core = try SampleTransport()
    let a = try core.load(tonalAsset(seconds: 0.1), deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000), sourceFrame: 4000.5, keylock: true)
    try core.setMasterBPM(96); try core.play(deck: .a, generation: a)
    let audio = core.renderOffline(frames: 48000)
    #expect(audio.left.allSatisfy { $0.isFinite })
    #expect(audio.left.suffix(40000).allSatisfy { $0 == 0 })
    #expect(core.snapshot()?.a.sourceFrame == 4800)
    #expect(core.snapshot()?.a.phase == .ended)
}

@Test func unsupportedKeylockRatiosAreRejectedWithoutChangingTempoOrSource() throws {
    let (core, generation) = try preparedTone(speed: 1.1, keylock: true)
    _ = core.renderOffline(frames: 1000); _ = core.acknowledgements()
    let before = try #require(core.snapshot())
    try core.setMasterBPM(1000); core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .keylockRate)
    #expect(core.snapshot()?.masterBPM == before.masterBPM)
    #expect(core.snapshot()?.a.sourceFrame == before.a.sourceFrame)
    try core.setKeylock(false, deck: .a, generation: generation)
    try core.setMasterBPM(1000); core.processControlsWhileIdle(); _ = core.acknowledgements()
    try core.setKeylock(true, deck: .a, generation: generation); core.processControlsWhileIdle()
    #expect(core.acknowledgements().last?.error == .keylockRate)
    #expect(core.snapshot()?.a.keylock == false)
}

@Test func keylockRejectsUnsafeOutputRateBeforeFFTConfiguration() {
    for rate in [0.0, Double.nan, Double.infinity, Double.greatestFiniteMagnitude, 1, 1000000] {
        #expect(throws: TransportError.self) { try SampleTransport(sampleRate: rate) }
    }
}

@Test func keylockRetainsTheComponentsOfAPolyphonicChord() throws {
    let frequencies = [220.0,277.18263098,329.62755691]
    var samples = [Float](repeating: 0, count: 48000*4*2)
    for i in 0..<(samples.count/2) {
        let value = frequencies.reduce(0.0) { $0+0.06*sin(2 * .pi * $1*Double(i)/48000) }
        samples[2*i] = Float(value); samples[2*i+1] = Float(value)
    }
    let core = try SampleTransport()
    let a = try core.load(PCMAsset(interleavedStereo: samples, sampleRate: 48000), deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000), keylock: true)
    try core.setMasterBPM(150); try core.play(deck: .a, generation: a)
    let output = core.renderOffline(frames: 96000).left
    func amplitude(_ frequency: Double) -> Double {
        var real = 0.0, imaginary = 0.0
        for i in 48000..<96000 {
            let phase = 2 * .pi * frequency*Double(i)/48000
            real += Double(output[i])*cos(phase); imaginary += Double(output[i])*sin(phase)
        }
        return 2*hypot(real,imaginary)/48000
    }
    for frequency in frequencies {
        #expect(amplitude(frequency) > 0.02)
        #expect(amplitude(frequency*1.25) < 0.003)
    }
}

@Test func rapidTempoChangesKeepEveryWetSampleAndCrossUnityWithoutPhaseResets() throws {
    let core = try SampleTransport()
    let a = try core.load(tonalAsset(seconds: 8), deck: .a,
        grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000), keylock: true)
    try core.play(deck: .a, generation: a)
    var audio: [Float] = []
    var call = 0
    while audio.count < 48000*6 {
        let phase = call%97
        let bpm = 108+(phase<=48 ? phase/2 : (96-phase)/2)
        try core.setMasterBPM(Double(bpm))
        audio += core.renderOffline(frames: min(127,48000*6-audio.count)).left
        _ = core.acknowledgements();call += 1
    }
    var maximumStep: Float = 0
    for i in 24001..<audio.count { maximumStep = max(maximumStep,abs(audio[i]-audio[i-1])) }
    #expect(maximumStep < 0.01)
    for start in stride(from: 24000, through: audio.count-24000, by: 24000) {
        let frequency = measuredFrequency(audio[start..<start+24000], rate: 48000)
        #expect(abs(1200*log2(frequency/440)) < 3)
    }
}
