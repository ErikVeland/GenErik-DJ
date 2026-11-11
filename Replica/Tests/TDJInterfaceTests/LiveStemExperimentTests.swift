import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private final class CancellableStemSeparator: LiveVocalSeparating, @unchecked Sendable {
    private let lock = NSLock()
    private var entered = false
    private var cancelled = false
    var didEnter: Bool { lock.withLock { entered } }
    var didCancel: Bool { lock.withLock { cancelled } }

    func vocals(in input: [Float]) throws -> [Float] {
        lock.withLock { entered = true }
        while !Task.isCancelled {
            Thread.sleep(forTimeInterval: 0.001)
        }
        lock.withLock { cancelled = true }
        return .init(repeating: 0.1, count: 2 * SpleeterVocalMask.outputFrames)
    }
}

private struct PreparedStemSeparator: LiveVocalSeparating {
    func vocals(in input: [Float]) throws -> [Float] {
        .init(repeating: 0.1, count: 2 * SpleeterVocalMask.outputFrames)
    }
}

@MainActor private final class LiveStemTestPlayback: LiveStemPlayback {
    let core: SampleTransport
    var callbackSummary: AudioCallbackSummary? { nil }
    init() throws { core = try SampleTransport(sampleRate: 44_100) }
}

@MainActor private func liveStemPlayback() throws -> LiveStemTestPlayback {
    let playback = try LiveStemTestPlayback()
    for deck in DeckID.primary {
        let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.2, count: 44_100 * 2), sampleRate: 44_100)
        let generation = try playback.core.load(asset, deck: deck, grid: nil, synced: false, keylock: false)
        try playback.core.play(deck: deck, generation: generation)
    }
    _ = playback.core.renderOffline(frames: 512)
    return playback
}

@Test @MainActor func liveStemsRemainInactiveUntilEnabled() throws {
    let playback = try liveStemPlayback()
    let separator = CancellableStemSeparator()
    let experiment = LiveStemExperiment(makeSeparator: { separator })
    experiment.select(.vocal, deck: .a, playback: playback)
    #expect(!experiment.isEnabled)
    #expect(!experiment.isSeparating)
    #expect(experiment.deck == nil)
    #expect(!separator.didEnter)
    #expect(!experiment.canSelect(.vocal, deck: .a))
}

@Test(.timeLimit(.minutes(1)), arguments: [true, false]) @MainActor
func liveStemsCancelPreparationAndPreservePlayback(disableSetting: Bool) async throws {
    let playback = try liveStemPlayback()
    let separator = CancellableStemSeparator()
    let experiment = LiveStemExperiment(makeSeparator: { separator })
    experiment.setEnabled(true, playback: playback)
    experiment.select(.vocal, deck: .a, playback: playback)
    for _ in 0..<1000 {
        if separator.didEnter { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    try #require(separator.didEnter)
    let before = try #require(playback.core.snapshot())
    if disableSetting {
        experiment.setEnabled(false, playback: playback)
    } else {
        experiment.select(.mix, deck: .a, playback: playback)
    }
    #expect(experiment.mode == .mix)
    #expect(experiment.isStopping)
    #expect(!experiment.canSelect(.vocal, deck: .a))
    for _ in 0..<1000 {
        if !experiment.isSeparating { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(separator.didCancel)
    #expect(!experiment.isSeparating)
    #expect(!experiment.isStopping)
    #expect(experiment.end == 0)
    #expect(!experiment.canSelect(.vocal, deck: .a))
    let output = playback.core.renderOffline(frames: 512)
    #expect(output.left.allSatisfy { $0.isFinite && $0 > 0 })
    let after = try #require(playback.core.snapshot())
    #expect(after.a.sourceFrame == before.a.sourceFrame + 512)
    #expect(after.b.sourceFrame == before.b.sourceFrame + 512)
    #expect(after.a.phase == .playing && after.b.phase == .playing)
}

@Test(.timeLimit(.minutes(1))) @MainActor func liveStemsCanUsePreparedAudioWithoutRestartingTheWorker() async throws {
    let playback = try liveStemPlayback()
    let experiment = LiveStemExperiment(makeSeparator: { PreparedStemSeparator() })
    experiment.setEnabled(true, playback: playback)
    experiment.select(.vocal, deck: .a, playback: playback)
    for _ in 0..<1000 {
        if !experiment.isSeparating { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    try #require(!experiment.isSeparating)
    try #require(experiment.end > experiment.first)
    let preparedEnd = experiment.end
    experiment.select(.mix, deck: .a, playback: playback)
    #expect(experiment.canSelect(.vocal, deck: .a))
    experiment.select(.instrumental, deck: .a, playback: playback)
    #expect(experiment.mode == .instrumental)
    #expect(!experiment.isSeparating)
    #expect(experiment.end == preparedEnd)
    #expect(experiment.isCovered(in: playback.core.snapshot()))
    #expect(!experiment.canSelect(.vocal, deck: .b))
    experiment.setEnabled(false, playback: playback)
    #expect(experiment.mode == .mix)
    #expect(!experiment.canSelect(.vocal, deck: .a))
    experiment.setEnabled(true, playback: playback)
    #expect(experiment.canSelect(.vocal, deck: .a))
    #expect(!experiment.isSeparating)
}

@Test(.timeLimit(.minutes(1))) @MainActor func liveStemWorkerStopsWhenTheExperimentIsReleased() async throws {
    let playback = try liveStemPlayback()
    let separator = CancellableStemSeparator()
    var experiment: LiveStemExperiment? = LiveStemExperiment(makeSeparator: { separator })
    weak var released = experiment
    experiment?.setEnabled(true, playback: playback)
    experiment?.select(.vocal, deck: .a, playback: playback)
    for _ in 0..<1000 {
        if separator.didEnter { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    try #require(separator.didEnter)
    experiment = nil
    #expect(released == nil)
    for _ in 0..<1000 {
        if separator.didCancel { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(separator.didCancel)
}

@Test func liveStemExperimentLoadsAndRunsBundledSpleeter() throws {
    let separator = try SpleeterVocalMask()
    var input = [Float](repeating: 0, count: 2 * SpleeterVocalMask.inputFrames)
    for frame in 0..<SpleeterVocalMask.inputFrames {
        input[2 * frame] = 0.2 * sin(Float(frame) * 0.07)
        input[2 * frame + 1] = 0.3 * sin(Float(frame) * 0.13)
    }
    let vocals = try separator.vocals(in: input)
    #expect(vocals.count == 2 * SpleeterVocalMask.outputFrames)
    #expect(vocals.allSatisfy { $0.isFinite })
    #expect(vocals.contains { abs($0) > 0.00001 })
}

@Test func liveStemExperimentPreservesBothDecksAndFallsBack() throws {
    let core = try SampleTransport(sampleRate: 44_100, outputGain: 1)
    let a = try PCMAsset(interleavedStereo: .init(repeating: 0.4, count: 44_100 * 2), sampleRate: 44_100)
    let b = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 44_100 * 2), sampleRate: 44_100)
    let genA = try core.load(a, deck: .a, grid: nil, synced: false, keylock: false)
    let genB = try core.load(b, deck: .b, grid: nil, synced: false, keylock: false)
    try core.play(deck: .a, generation: genA)
    try core.play(deck: .b, generation: genB)
    let original = try #require(core.renderOffline(frames: 512).left.last)

    #expect(core.beginLiveVocal(deck: .a, generation: genA, first: 0, capacity: 8192))
    let waiting = try #require(core.renderOffline(frames: 512).left.last)
    #expect(abs(waiting - original) < 0.001)

    let vocal = [Float](repeating: 0.1, count: 8192 * 2)
    #expect(vocal.withUnsafeBufferPointer(core.appendLiveVocal))
    let frame = try #require(core.snapshot()).a.sourceFrame
    let isolated = try #require(core.renderOffline(frames: 512).left.last)
    #expect(abs(isolated / original - 0.4) < 0.01)
    #expect(try #require(core.snapshot()).a.sourceFrame == frame + 512)
    #expect(try #require(core.snapshot()).b.sourceFrame == frame + 512)

    core.setLiveVocalMode(2)
    let instrumental = try #require(core.renderOffline(frames: 512).left.last)
    #expect(abs(instrumental / original - 0.8) < 0.01)
    _ = core.renderOffline(frames: 4096)
    let fallback = try #require(core.renderOffline(frames: 512).left.last)
    #expect(abs(fallback - original) < 0.001)
}
