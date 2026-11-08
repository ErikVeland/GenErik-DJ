import Foundation
import Testing

@testable import TDJCore

private let benchmarkHash = String(repeating: "a", count: 64)
private let benchmarkLimits = AnalysisBenchmarkLimits(
    maximumBPMError: 0.02, maximumBeatPhaseErrorMilliseconds: 10, maximumGridDriftMilliseconds: 20,
    maximumDownbeatErrorMilliseconds: 20, maximumSimilarEnergyDistance: 1)

private func annotatedTrack(_ id: String = "reference") -> AnalysisBenchmarkTrack {
    .init(
        id: id, path: "reference.wav", sha256: benchmarkHash, annotation: "Synthetic scorer test, not TDJ1 evidence.",
        tags: ["test"], tempo: .init(status: .labelled, bpm: 120, beatAnchorSeconds: 0),
        key: .init(status: .labelled, key: .init(tonic: 0, mode: .major)),
        downbeat: .init(status: .labelled, barStartSeconds: 0))
}

private func measuredAnalysis(
    bpm: Double = 120, anchorSeconds: Double = 0, key: MusicalKey = .init(tonic: 0, mode: .major), downbeat: Int? = 0
) -> AudioAnalysis {
    var result = AudioAnalysis(
        implementation: "Synthetic scorer test", configurationID: "test", contentSHA256: benchmarkHash,
        sampleRate: 48000, frameCount: 48000 * 600, channelCount: 2, waveformFramesPerBin: 480, waveform: [], bpm: bpm,
        beatAnchorFrame: anchorSeconds * 48000, tempoConfidence: 1, key: key, keyConfidence: 1, chroma: [], timbre: [])
    result.cachedEnergyLevel = 5
    result.detectedDownbeatOffset = downbeat
    result.downbeatConfidence = downbeat == nil ? nil : 0.9
    return result
}

private func benchmarkManifest() -> AnalysisBenchmarkManifest {
    .init(
        format: "tdj1.analysis-benchmark/v1", corpus: .synthetic, referenceBuild: nil, requiredTags: ["test"],
        limits: benchmarkLimits, tracks: [annotatedTrack("a"), annotatedTrack("b")],
        energyComparisons: [
            .init(firstTrackID: "a", secondTrackID: "b", relation: .similar, annotation: "Equal synthetic energy.")
        ])
}

@Test func exactTempoAndLongTrackDriftAreIndependentAcceptanceChecks() throws {
    let result = AnalysisBenchmark.evaluate(
        measuredAnalysis(bpm: 120.01), expected: annotatedTrack(), limits: benchmarkLimits)
    #expect(result.checks.first { $0.metric == "bpm" }?.outcome == .pass)
    #expect(result.checks.first { $0.metric == "gridDriftMilliseconds" }?.outcome == .fail)
    #expect(try #require(result.checks.first { $0.metric == "gridDriftMilliseconds" }?.error) > 49)
}

@Test func doubledTempoNeverReceivesOctaveEquivalenceCredit() {
    let result = AnalysisBenchmark.evaluate(
        measuredAnalysis(bpm: 240), expected: annotatedTrack(), limits: benchmarkLimits)
    #expect(result.checks.first { $0.metric == "bpm" }?.outcome == .fail)
    #expect(result.checks.first { $0.metric == "gridDriftMilliseconds" }?.outcome == .fail)
}

@Test func relativeKeyIsNotAnExactKeyDetection() {
    let result = AnalysisBenchmark.evaluate(
        measuredAnalysis(key: .init(tonic: 9, mode: .minor)), expected: annotatedTrack(), limits: benchmarkLimits)
    #expect(result.checks.first { $0.metric == "key" }?.outcome == .fail)
}

@Test func correctBeatPhaseDoesNotHideWrongBarPhase() {
    for offset in [1, 2, 3] {
        let result = AnalysisBenchmark.evaluate(
            measuredAnalysis(downbeat: offset), expected: annotatedTrack(), limits: benchmarkLimits)
        #expect(result.checks.first { $0.metric == "beatPhaseMilliseconds" }?.outcome == .pass)
        #expect(result.checks.first { $0.metric == "downbeat" }?.outcome == .fail)
    }
}

@Test func defaultOrManualGridDoesNotCountAsAutomaticDownbeatDetection() throws {
    let analysis = measuredAnalysis(downbeat: nil)
    var track = try Track(title: "Manual", mediaFilename: "manual.wav", analysis: analysis)
    track.preparation.gridIsManual = true
    try track.preparation.grid?.selectDownbeat(0)
    let result = AnalysisBenchmark.evaluate(track.analysis, expected: annotatedTrack(), limits: benchmarkLimits)
    #expect(result.checks.first { $0.metric == "downbeat" }?.outcome == .fail)
}

@Test func beatAnchorsMayDifferByWholeBarsWithoutChangingTheGrid() {
    let result = AnalysisBenchmark.evaluate(
        measuredAnalysis(anchorSeconds: 8), expected: annotatedTrack(), limits: benchmarkLimits)
    #expect(result.checks.allSatisfy { $0.outcome == .pass })
}

@Test func wrongAudioHashCannotEarnMusicalScores() {
    var expected = annotatedTrack()
    expected.sha256 = String(repeating: "b", count: 64)
    let result = AnalysisBenchmark.evaluate(measuredAnalysis(), expected: expected, limits: benchmarkLimits)
    #expect(result.checks.count == 1)
    #expect(result.checks.first?.metric == "source")
    #expect(result.checks.first?.outcome == .fail)
}

@Test func syntheticSuccessNeverClaimsReferenceParity() throws {
    let manifest = benchmarkManifest()
    try manifest.validate()
    let results = manifest.tracks.map {
        AnalysisBenchmark.evaluate(measuredAnalysis(), expected: $0, limits: manifest.limits)
    }
    let report = AnalysisBenchmark.report(manifest: manifest, measurements: results)
    #expect(report.labelledChecksPassed)
    #expect(!report.referenceCorpusPassed)
    #expect(report.blockers.contains { $0.contains("Synthetic") })
    #expect(report.energyChecks.first?.outcome == .pass)
}

@Test func missingLabelsCoverageAndEnergyCannotProduceAnAcceptancePass() throws {
    var manifest = benchmarkManifest()
    manifest.corpus = .tdj1Reference
    manifest.referenceBuild = "1.6.8.67"
    manifest.requiredTags = ["test", "detuned"]
    manifest.energyComparisons = []
    manifest.tracks[0].key = .init(status: .unlabelled)
    let results = manifest.tracks.map {
        AnalysisBenchmark.evaluate(measuredAnalysis(), expected: $0, limits: manifest.limits)
    }
    let report = AnalysisBenchmark.report(manifest: manifest, measurements: results)
    #expect(!report.referenceCorpusPassed)
    #expect(report.blockers.contains { $0.contains("detuned") })
    #expect(report.blockers.contains { $0.contains("Unlabelled") })
    #expect(report.blockers.contains { $0.contains("energy comparisons") })
}

@Test func absentOnlyCorpusCannotClaimDetectionQuality() {
    var manifest = benchmarkManifest()
    manifest.corpus = .tdj1Reference
    manifest.referenceBuild = "1.6.8.67"
    for index in manifest.tracks.indices {
        manifest.tracks[index].tempo = .init(status: .absent)
        manifest.tracks[index].key = .init(status: .absent)
        manifest.tracks[index].downbeat = .init(status: .absent)
    }
    let report = AnalysisBenchmark.report(manifest: manifest, measurements: [])
    #expect(!report.referenceCorpusPassed)
    #expect(report.blockers.filter { $0.contains("positive labelled") }.count == 3)
}

@Test func energyOrderingAndGainInvarianceAreBothMeasurable() {
    var manifest = benchmarkManifest()
    manifest.energyComparisons[0].relation = .higher
    var quiet = measuredAnalysis()
    quiet.cachedEnergyLevel = 2
    let results = [
        AnalysisBenchmark.evaluate(measuredAnalysis(), expected: manifest.tracks[0], limits: manifest.limits),
        AnalysisBenchmark.evaluate(quiet, expected: manifest.tracks[1], limits: manifest.limits),
    ]
    #expect(AnalysisBenchmark.report(manifest: manifest, measurements: results).energyChecks.first?.outcome == .pass)
    manifest.energyComparisons[0].relation = .similar
    #expect(AnalysisBenchmark.report(manifest: manifest, measurements: results).energyChecks.first?.outcome == .fail)
}

@Test func invalidBenchmarkAnnotationsAreRejected() {
    var manifest = benchmarkManifest()
    manifest.tracks[0].downbeat.barStartSeconds = 0.25
    #expect(throws: CoreError.self) { try manifest.validate() }
    manifest = benchmarkManifest()
    manifest.tracks[0].tempo.bpm = .nan
    #expect(throws: CoreError.self) { try manifest.validate() }
    manifest = benchmarkManifest()
    manifest.energyComparisons[0].secondTrackID = "missing"
    #expect(throws: CoreError.self) { try manifest.validate() }
    manifest = benchmarkManifest()
    manifest.energyComparisons.append(manifest.energyComparisons[0])
    #expect(throws: CoreError.self) { try manifest.validate() }
}

@Test func missingAudioIsRetainedAsAFailedCase() async throws {
    var manifest = benchmarkManifest()
    manifest.tracks = [annotatedTrack()]
    manifest.energyComparisons = []
    let report = try await AnalysisBenchmark.run(
        manifest: manifest, relativeTo: URL(fileURLWithPath: "/no-such-tdj-corpus"))
    #expect(report.tracks.count == 1)
    #expect(report.tracks.first?.checks.first?.outcome == .fail)
    #expect(report.tracks.first?.performance?.outcome == "failed")
    #expect(report.tracks.first?.performance?.jobID == manifest.tracks.first?.id)
    #expect(!report.labelledChecksPassed)
    #expect(!report.referenceCorpusPassed)
}

@Test func automaticDownbeatProvenanceSurvivesWaveformCompactionAndLegacyDecoding() throws {
    let analysis = measuredAnalysis(downbeat: 3)
    let compact = analysis.replacingWaveform([])
    #expect(compact.detectedDownbeatOffset == 3)
    #expect(compact.downbeatConfidence == 0.9)
    let track = try Track(title: "Automatic", mediaFilename: "automatic.wav", analysis: compact)
    #expect(track.grid?.downbeatOffset == 3)
    let restored = try JSONDecoder().decode(AudioAnalysis.self, from: JSONEncoder().encode(compact))
    #expect(restored.detectedDownbeatOffset == 3)
    let legacy = measuredAnalysis(downbeat: nil)
    let data = try JSONEncoder().encode(legacy)
    #expect(!String(decoding: data, as: UTF8.self).contains("detectedDownbeatOffset"))
    #expect(try JSONDecoder().decode(AudioAnalysis.self, from: data).detectedDownbeatOffset == nil)
}

@Test func variableTempoMapCannotBeHiddenByACorrectAverageBPM() throws {
    var expected = annotatedTrack("a")
    expected.tempo.beatTimesSeconds = [0, 0.5, 1.05, 1.55, 2, 2.5, 3.05, 3.55, 4]
    expected.downbeat.barTimesSeconds = [0, 2, 4]
    let result = AnalysisBenchmark.evaluate(measuredAnalysis(), expected: expected, limits: benchmarkLimits)
    #expect(result.checks.first { $0.metric == "bpm" }?.outcome == .pass)
    #expect(result.checks.first { $0.metric == "gridDriftMilliseconds" }?.outcome == .fail)
    #expect(try #require(result.checks.first { $0.metric == "gridDriftMilliseconds" }?.error) > 49)
    var manifest = benchmarkManifest()
    manifest.tracks[0] = expected
    try manifest.validate()
    manifest.tracks[0].downbeat.barTimesSeconds = [0, 2.5, 4]
    #expect(throws: CoreError.self) { try manifest.validate() }
}

@Test func invalidAutomaticDownbeatMetadataCannotBePersisted() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var snapshot = LibrarySnapshot()
    snapshot.tracks = [try Track(title: "Validation", mediaFilename: "test.wav", analysis: measuredAnalysis())]
    snapshot.tracks[0].analysis.detectedDownbeatOffset = 4
    #expect(throws: CoreError.self) { try store.save(snapshot) }
    snapshot.tracks[0].analysis.detectedDownbeatOffset = nil
    #expect(throws: CoreError.self) { try store.save(snapshot) }
    snapshot.tracks[0].analysis.detectedDownbeatOffset = 0
    snapshot.tracks[0].analysis.downbeatConfidence = 1.1
    #expect(throws: CoreError.self) { try store.save(snapshot) }
}
