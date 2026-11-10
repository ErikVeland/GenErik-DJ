import Foundation
import Testing

@testable import TDJCore

private func deepTestAnalysis() throws -> AudioAnalysis {
    try syntheticTrack("a", bpm: 120).analysis.replacingWaveform(
        [], configurationID: "test", frameCount: 4_410_000, decodedFrames: nil)
}

private func emptyWindow(_ index: Int, _ start: Int) -> DeepPredictionWindow {
    .init(
        index: index, start: start, beats: .init(repeating: -10, count: 1500),
        downbeats: .init(repeating: -10, count: 1500))
}

@Test func deepAdaptiveUpgradeSkipsPreviouslyResolvedConstantFits() throws {
    let analysis = try deepTestAnalysis()
    let current = DeepAnalysisProfile.current
    let previous = DeepAnalysisProfile(
        generation: 3, model: current.model, weightsSHA256: current.weightsSHA256,
        conversion: current.conversion, preprocessing: current.preprocessing, decisionPolicy: 3,
        upgradeBenefit: "Earlier constant-grid policy.")
    let candidate = DeepBeatCandidate(.init(
        bpm: 120, firstBar: 0, beatAgreement: 0.98, barAgreement: 0.96, residualMilliseconds: 8))
    let resolved = DeepBeatAnalysis(
        audio: .init(analysis), profile: previous, coveredFrames: analysis.frameCount,
        windowCount: BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(analysis)).count,
        candidate: candidate)
    let unresolved = DeepBeatAnalysis(
        audio: resolved.audio, profile: previous, coveredFrames: resolved.coveredFrames,
        windowCount: resolved.windowCount, candidate: nil)
    #expect(!current.needsAnalysis(after: resolved))
    #expect(current.needsAnalysis(after: unresolved))
    let weak = DeepBeatAnalysis(
        audio: resolved.audio, profile: previous, coveredFrames: resolved.coveredFrames,
        windowCount: resolved.windowCount, candidate: .init(.init(
            bpm: 120, firstBar: 0, beatAgreement: 0.85, barAgreement: 0.95,
            residualMilliseconds: 30)))
    #expect(current.needsAnalysis(after: weak))
    let policyFour = DeepAnalysisProfile(
        generation: 4, model: current.model, weightsSHA256: current.weightsSHA256,
        conversion: current.conversion, preprocessing: current.preprocessing, decisionPolicy: 4,
        upgradeBenefit: "Review missing constant fits.")
    let previouslyReviewed = DeepBeatAnalysis(
        audio: resolved.audio, profile: policyFour, coveredFrames: resolved.coveredFrames,
        windowCount: resolved.windowCount, candidate: nil)
    #expect(!current.needsAnalysis(after: previouslyReviewed))
    let previouslyWeak = DeepBeatAnalysis(
        audio: resolved.audio, profile: policyFour, coveredFrames: resolved.coveredFrames,
        windowCount: resolved.windowCount, candidate: weak.candidate)
    #expect(current.needsAnalysis(after: previouslyWeak))
}

@Test func deepCheckpointsResumeOnlyUnfinishedWindows() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = DeepAnalysisCheckpoints(root: root, analysis: try deepTestAnalysis())
    #expect(throws: CancellationError.self) {
        try DeepBeatAnalyzer.run(checkpoints: store, progress: { _, _ in }, checkCancellation: {}) { index, start in
            if index == 1 { throw CancellationError() }
            return emptyWindow(index, start)
        }
    }
    #expect(store.result() == nil)
    #expect(store.read(0) != nil)
    var inferred: [Int] = []
    let resumed = DeepAnalysisCheckpoints(root: root, analysis: try deepTestAnalysis())
    let result = try DeepBeatAnalyzer.run(checkpoints: resumed, progress: { _, _ in }, checkCancellation: {}) {
        index, start in
        inferred.append(index)
        return emptyWindow(index, start)
    }
    #expect(inferred == Array(1..<store.starts.count))
    #expect(result.coveredFrames == 4_410_000)
    #expect(result.needsReview)
    #expect(resumed.result() == result)
    _ = try DeepBeatAnalyzer.run(checkpoints: resumed, progress: { _, _ in }, checkCancellation: {}) { _, _ in
        Issue.record("A completed profile must not repeat inference.")
        throw CancellationError()
    }
}

@Test func deepCheckpointsRejectDamageAndKeepVersionsSeparate() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let analysis = try deepTestAnalysis()
    let original = DeepAnalysisCheckpoints(root: root, analysis: analysis)
    try original.write(emptyWindow(0, original.starts[0]))
    let current = DeepAnalysisProfile.current
    let policyUpgrade = DeepAnalysisProfile(
        generation: current.generation + 1, model: current.model, weightsSHA256: current.weightsSHA256,
        conversion: current.conversion, preprocessing: current.preprocessing,
        decisionPolicy: current.decisionPolicy + 1, upgradeBenefit: "Improved candidate selection.")
    let newPolicy = DeepAnalysisCheckpoints(root: root, analysis: analysis, profile: policyUpgrade)
    #expect(newPolicy.read(0) != nil)
    let modelUpgrade = DeepAnalysisProfile(
        generation: current.generation + 1, model: "BeatThis/future", weightsSHA256: String(repeating: "b", count: 64),
        conversion: 1, preprocessing: 1, decisionPolicy: 2, upgradeBenefit: "Improved beat evidence.")
    #expect(DeepAnalysisCheckpoints(root: root, analysis: analysis, profile: modelUpgrade).read(0) == nil)
    let changedAudio = try syntheticTrack("b", bpm: 120).analysis
    #expect(DeepAnalysisCheckpoints(root: root, analysis: changedAudio).read(0) == nil)
    try Data("truncated".utf8).write(to: original.directory.appendingPathComponent("window-0.json"))
    #expect(original.read(0) == nil)
    let result = DeepBeatAnalysis(
        audio: .init(analysis), profile: .current, coveredFrames: analysis.frameCount,
        windowCount: original.starts.count, candidate: nil)
    #expect(throws: (any Error).self) { try original.finish(result) }
    #expect(current.needsAnalysis(after: result) == false)
    #expect(policyUpgrade.needsAnalysis(after: result))
    let future = DeepBeatAnalysis(
        audio: .init(analysis), profile: modelUpgrade, coveredFrames: analysis.frameCount,
        windowCount: original.starts.count, candidate: nil)
    #expect(!current.needsAnalysis(after: future))
}

@Test func deepAdoptionPreservesManualPreparationAndRejectsConflictingEvidence() throws {
    var track = try syntheticTrack("a", bpm: 120)
    let candidate = DeepBeatCandidate(
        .init(
            bpm: 120, firstBar: 0, beatAgreement: 0.98,
            barAgreement: 0.96, residualMilliseconds: 8))
    let result = DeepBeatAnalysis(
        audio: .init(track.analysis), profile: .current,
        coveredFrames: track.analysis.frameCount,
        windowCount: BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(track.analysis)).count,
        candidate: candidate)
    track.preparation.gridWasEditedByUser = true
    track.preparation.correctedKey = .init(tonic: 5, mode: .minor)
    let manual = try track.adoptingDeepAnalysis(result)
    #expect(manual.preparation == track.preparation)
    #expect(manual.keyGovernance == track.keyGovernance)
    #expect(manual.analysis.deepBeatAnalysis == result)
    #expect(try manual.adoptingDeepAnalysis(result) == manual)
    var changed = try syntheticTrack("a", bpm: 80)
    changed.analysis = track.analysis
    #expect(result.acceptedGrid(for: changed) == nil)
    let remote = try syntheticTrack("b", bpm: 120)
    #expect(throws: (any Error).self) { try remote.adoptingDeepAnalysis(result) }
    let copy = try JSONDecoder().decode(Track.self, from: JSONEncoder().encode(manual))
    #expect(copy.analysis.deepBeatAnalysis == result)
    #expect(copy.analysis.replacingWaveform([]).deepBeatAnalysis == result)
}

@Test func deepAcceptedEvidenceSurvivesLaterFirstPass() throws {
    let base = try syntheticTrack("a", bpm: 120)
    let accepted = DeepBeatAnalysis(
        audio: .init(base.analysis), profile: .current,
        coveredFrames: base.analysis.frameCount, windowCount: 1,
        candidate: .init(.init(bpm: 120, firstBar: 0, beatAgreement: 0.98, barAgreement: 0.96, residualMilliseconds: 8))
    )
    let prepared = try base.adoptingDeepAnalysis(accepted)
    #expect(prepared.analysis.acceptedDeepBeatAnalysis == accepted)
    var weak = base.analysis
    weak.bpm = 60
    let refreshed = weak.retainingDeepEvidence(from: prepared.analysis)
    #expect(refreshed.bpm == 120)
    #expect(refreshed.deepBeatAnalysis == accepted)
    #expect(refreshed.acceptedDeepBeatAnalysis == accepted)
    #expect(refreshed.replacingWaveform([]).acceptedDeepBeatAnalysis == accepted)
    #expect(
        refreshed.replacingWaveform([], configurationID: "changed", frameCount: 100, decodedFrames: nil)
            .deepBeatAnalysis == nil)
    let other = try syntheticTrack("b", bpm: 90).analysis.retainingDeepEvidence(from: prepared.analysis)
    #expect(other.deepBeatAnalysis == nil)
}

@Test func deepWindowStoragePreservesFloatBitsWithinBoundedSize() throws {
    var beats = [Float](repeating: 0.12345678, count: 1500)
    beats[0] = -.greatestFiniteMagnitude
    beats[1] = .leastNonzeroMagnitude
    beats[2] = -0.0
    let window = DeepPredictionWindow(index: 0, start: -6, beats: beats, downbeats: beats.reversed())
    let bytes = try JSONEncoder.sorted.encode(window)
    #expect(bytes.count < 20 * 1024)
    let restored = try JSONDecoder().decode(DeepPredictionWindow.self, from: bytes)
    #expect(restored.beats.map(\.bitPattern) == window.beats.map(\.bitPattern))
    #expect(restored.downbeats.map(\.bitPattern) == window.downbeats.map(\.bitPattern))
}
