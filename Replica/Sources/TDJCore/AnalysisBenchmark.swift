import Foundation

public enum AnalysisLabelStatus: String, Codable, Sendable {
    case labelled, absent, unlabelled
}

public struct TempoExpectation: Codable, Sendable {
    public var status: AnalysisLabelStatus
    public var bpm: Double?
    public var beatAnchorSeconds: Double?
    public var beatTimesSeconds: [Double]?
}

public struct KeyExpectation: Codable, Sendable {
    public var status: AnalysisLabelStatus
    public var key: MusicalKey?
}

public struct DownbeatExpectation: Codable, Sendable {
    public var status: AnalysisLabelStatus
    public var barStartSeconds: Double?
    public var barTimesSeconds: [Double]?
}

public struct AnalysisBenchmarkTrack: Codable, Sendable {
    public var id: String
    public var path: String
    public var sha256: String
    public var annotation: String
    public var tags: [String]
    public var tempo: TempoExpectation
    public var key: KeyExpectation
    public var downbeat: DownbeatExpectation
}

public struct EnergyExpectation: Codable, Sendable {
    public enum Relation: String, Codable, Sendable { case lower, similar, higher }
    public var firstTrackID: String
    public var secondTrackID: String
    public var relation: Relation
    public var annotation: String
}

/// Engineering acceptance limits, not measurements of NI's algorithm.
public struct AnalysisBenchmarkLimits: Codable, Sendable {
    public var maximumBPMError: Double
    public var maximumBeatPhaseErrorMilliseconds: Double
    public var maximumGridDriftMilliseconds: Double
    public var maximumDownbeatErrorMilliseconds: Double
    public var maximumSimilarEnergyDistance: Int
}

public struct AnalysisBenchmarkManifest: Codable, Sendable {
    public enum Corpus: String, Codable, Sendable { case synthetic, tdj1Reference }
    public var format: String
    public var corpus: Corpus
    public var referenceBuild: String?
    public var requiredTags: [String]
    public var limits: AnalysisBenchmarkLimits
    public var tracks: [AnalysisBenchmarkTrack]
    public var energyComparisons: [EnergyExpectation]

    public func validate() throws {
        func invalid(_ reason: String) -> CoreError { .invalidAudio("Invalid analysis benchmark: " + reason) }
        guard format == "tdj1.analysis-benchmark/v1" else { throw invalid("unsupported format.") }
        guard Set(tracks.map(\.id)).count == tracks.count else { throw invalid("duplicate track IDs.") }
        guard limits.maximumBPMError.isFinite, limits.maximumBPMError >= 0,
              limits.maximumBeatPhaseErrorMilliseconds.isFinite, limits.maximumBeatPhaseErrorMilliseconds >= 0,
              limits.maximumGridDriftMilliseconds.isFinite, limits.maximumGridDriftMilliseconds >= 0,
              limits.maximumDownbeatErrorMilliseconds.isFinite, limits.maximumDownbeatErrorMilliseconds >= 0,
              (0...10).contains(limits.maximumSimilarEnergyDistance) else { throw invalid("invalid limits.") }
        let identities = Set(tracks.map(\.id))
        func validTimes(_ times: [Double], origin: Double) -> Bool {
            times.count >= 2 && times.first == origin && times.allSatisfy { $0.isFinite && $0 >= 0 }
                && zip(times, times.dropFirst()).allSatisfy { $0 < $1 }
        }
        for track in tracks {
            guard !track.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !track.path.isEmpty, track.sha256.count == 64,
                  track.sha256.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
                  !track.annotation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw invalid("track identity, content hash and annotation are required.")
            }
            if track.tempo.status == .labelled {
                guard let bpm = track.tempo.bpm, bpm.isFinite, bpm > 0,
                      (60 / bpm).isFinite,
                      let anchor = track.tempo.beatAnchorSeconds, anchor.isFinite, anchor >= 0 else {
                    throw invalid("labelled tempo needs BPM and a beat anchor.")
                }
                if let times = track.tempo.beatTimesSeconds,
                   !validTimes(times, origin: track.tempo.beatAnchorSeconds!) {
                    throw invalid("beat map needs increasing consecutive beat times starting at its anchor.")
                }
            } else if track.tempo.bpm != nil || track.tempo.beatAnchorSeconds != nil {
                throw invalid("unlabelled or absent tempo must not contain a value.")
            }
            if track.tempo.status != .labelled && track.tempo.beatTimesSeconds != nil {
                throw invalid("beat maps require a labelled tempo.")
            }
            guard (track.key.status == .labelled) == (track.key.key != nil) else {
                throw invalid("key label and value disagree.")
            }
            if track.downbeat.status == .labelled {
                guard track.tempo.status == .labelled,
                      let bar = track.downbeat.barStartSeconds, bar.isFinite, bar >= 0 else {
                    throw invalid("labelled downbeat needs a bar start and labelled tempo.")
                }
                let period = 60 / track.tempo.bpm!
                let distance = (bar - track.tempo.beatAnchorSeconds!) / period
                guard track.tempo.beatTimesSeconds.map({ times in times.contains { abs($0 - bar) < 0.000001 } })
                    ?? (abs(distance - distance.rounded()) < 0.0001) else {
                    throw invalid("reference downbeat must lie on the reference beatgrid.")
                }
                if let times = track.downbeat.barTimesSeconds {
                    guard validTimes(times, origin: bar) else { throw invalid("invalid bar map.") }
                    if let beats = track.tempo.beatTimesSeconds {
                        guard let firstBeat = beats.firstIndex(where: { abs($0 - bar) < 0.000001 }),
                              times.enumerated().allSatisfy({ index, time in
                                  let beat = firstBeat + index * 4
                                  return beat < beats.count && abs(beats[beat] - time) < 0.000001
                              }) else { throw invalid("bar map must follow every fourth annotated beat.") }
                    }
                }
            } else if track.downbeat.barStartSeconds != nil {
                throw invalid("unlabelled or absent downbeat must not contain a value.")
            }
            if track.downbeat.status != .labelled && track.downbeat.barTimesSeconds != nil {
                throw invalid("bar maps require a labelled downbeat.")
            }
        }
        var pairs = Set<String>()
        for pair in energyComparisons {
            let identity = [pair.firstTrackID, pair.secondTrackID].sorted().joined(separator: "\u{0}")
            guard pair.firstTrackID != pair.secondTrackID, identities.contains(pair.firstTrackID),
                  identities.contains(pair.secondTrackID), pairs.insert(identity).inserted,
                  !pair.annotation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw invalid("energy comparisons need distinct known tracks, unique pairs and an annotation.")
            }
        }
    }
}

public struct AnalysisBenchmarkCheck: Codable, Sendable {
    public enum Outcome: String, Codable, Sendable { case pass, fail, unlabelled }
    public var metric: String
    public var outcome: Outcome
    public var detail: String
    public var error: Double?
    public var limit: Double?
}

public struct AnalysisBenchmarkMeasurement: Codable, Sendable {
    public var id: String
    public var contentSHA256: String?
    public var configurationID: String?
    public var implementation: String?
    public var durationSeconds: Double?
    public var elapsedSeconds: Double
    public var bpm: Double?
    public var beatAnchorSeconds: Double?
    public var tempoConfidence: Double?
    public var key: MusicalKey?
    public var keyConfidence: Double?
    public var energyLevel: Int?
    public var detectedDownbeatOffset: Int?
    public var downbeatConfidence: Double?
    public var checks: [AnalysisBenchmarkCheck]
}

public struct AnalysisBenchmarkReport: Codable, Sendable {
    public var format = "tdj1.analysis-benchmark-report/v1"
    public var manifest: AnalysisBenchmarkManifest
    public var corpus: AnalysisBenchmarkManifest.Corpus
    public var referenceBuild: String?
    public var limits: AnalysisBenchmarkLimits
    public var tracks: [AnalysisBenchmarkMeasurement]
    public var energyChecks: [AnalysisBenchmarkCheck]
    public var blockers: [String]
    public var labelledChecksPassed: Bool
    public var referenceCorpusPassed: Bool
    public var fidelityStatus = "Full TDJ1 fidelity remains unverified; a corpus result covers only its annotated cases."
}

public enum AnalysisBenchmark {
    public static let requiredReferenceTags = ["four-on-floor", "broken-beat", "syncopated", "live-drums",
        "ambient", "pickup", "breakdown", "half-double-ambiguity", "detuned", "mastering-variation", "long-track", "tempo-drift"]
    public static func run(manifest: AnalysisBenchmarkManifest, relativeTo directory: URL) async throws -> AnalysisBenchmarkReport {
        try manifest.validate()
        var measurements: [AnalysisBenchmarkMeasurement] = []
        for track in manifest.tracks {
            try Task.checkCancellation()
            let started = ContinuousClock.now
            do {
                let url = URL(fileURLWithPath: track.path, relativeTo: directory).standardizedFileURL
                let analysis = try await AnalysisWorker.shared.analyze(url: url)
                let elapsed = started.duration(to: .now)
                measurements.append(evaluate(analysis, expected: track, limits: manifest.limits,
                    elapsedSeconds: Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18))
            } catch is CancellationError { throw CancellationError() }
            catch {
                let elapsed = started.duration(to: .now)
                measurements.append(.init(id: track.id,
                    elapsedSeconds: Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18,
                    checks: [.init(metric: "source", outcome: .fail, detail: error.localizedDescription)]))
            }
        }
        return report(manifest: manifest, measurements: measurements)
    }

    static func evaluate(_ analysis: AudioAnalysis, expected: AnalysisBenchmarkTrack,
                         limits: AnalysisBenchmarkLimits, elapsedSeconds: Double = 0) -> AnalysisBenchmarkMeasurement {
        var result = AnalysisBenchmarkMeasurement(id: expected.id, contentSHA256: analysis.contentSHA256,
            configurationID: analysis.configurationID, implementation: analysis.implementation,
            durationSeconds: analysis.duration, elapsedSeconds: elapsedSeconds, bpm: analysis.bpm,
            beatAnchorSeconds: analysis.beatAnchorFrame.map { $0 / analysis.sampleRate },
            tempoConfidence: analysis.tempoConfidence, key: analysis.key, keyConfidence: analysis.keyConfidence,
            energyLevel: PerformerSuggestions.energyLevel(analysis), detectedDownbeatOffset: analysis.detectedDownbeatOffset,
            downbeatConfidence: analysis.downbeatConfidence, checks: [])
        func check(_ metric: String, _ pass: Bool, _ detail: String, error: Double? = nil, limit: Double? = nil) -> AnalysisBenchmarkCheck {
            .init(metric: metric, outcome: pass ? .pass : .fail, detail: detail, error: error, limit: limit)
        }
        guard expected.sha256 == analysis.contentSHA256 else {
            result.checks = [check("source", false, "Audio hash differs from the annotated source; no musical scores were accepted.")]
            return result
        }
        result.checks.append(check("source", true, "Audio content matches the annotated SHA-256."))
        switch expected.tempo.status {
        case .unlabelled:
            result.checks.append(.init(metric: "tempo", outcome: .unlabelled, detail: "No reference tempo/grid annotation."))
        case .absent:
            result.checks.append(check("tempo", analysis.bpm == nil && analysis.beatAnchorFrame == nil, "Expected no tempo or grid."))
        case .labelled:
            if let bpm = analysis.bpm, bpm.isFinite, bpm > 0, let anchor = result.beatAnchorSeconds,
               anchor.isFinite, let expectedBPM = expected.tempo.bpm, let expectedAnchor = expected.tempo.beatAnchorSeconds,
               expectedAnchor < analysis.duration,
               expected.tempo.beatTimesSeconds?.last.map({ $0 < analysis.duration }) ?? true {
                let bpmError = abs(bpm - expectedBPM)
                result.checks.append(check("bpm", bpmError <= limits.maximumBPMError,
                    "Exact tempo; half/double estimates receive no equivalence credit.", error: bpmError, limit: limits.maximumBPMError))
                let expectedPeriod = 60 / expectedBPM
                let period = 60 / bpm
                let firstDetectedBeat = ((expectedAnchor - anchor) / period).rounded()
                let signedPhase = anchor + firstDetectedBeat * period - expectedAnchor
                let phaseError = abs(signedPhase) * 1000
                result.checks.append(check("beatPhaseMilliseconds", phaseError <= limits.maximumBeatPhaseErrorMilliseconds,
                    "Nearest detected beat at the annotated grid origin.", error: phaseError, limit: limits.maximumBeatPhaseErrorMilliseconds))
                let lastBeat = floor((analysis.duration - 1 / analysis.sampleRate - expectedAnchor) / expectedPeriod)
                let endError = abs(signedPhase + lastBeat * (period - expectedPeriod)) * 1000
                let drift: Double
                if let times = expected.tempo.beatTimesSeconds {
                    drift = times.enumerated().map { index, time in
                        abs(anchor + (firstDetectedBeat + Double(index)) * period - time) * 1000
                    }.max() ?? .infinity
                } else { drift = max(phaseError, endError) }
                result.checks.append(check("gridDriftMilliseconds", drift <= limits.maximumGridDriftMilliseconds,
                    "Maximum error across the annotated beat map, or start/end for a constant grid; no phase wrapping or beat reassignment.",
                    error: drift, limit: limits.maximumGridDriftMilliseconds))
            } else {
                result.checks.append(check("tempo", false, "Missing/invalid automatic BPM or beat anchor, or annotation outside the file."))
            }
        }
        switch expected.key.status {
        case .unlabelled:
            result.checks.append(.init(metric: "key", outcome: .unlabelled, detail: "No reference key annotation."))
        case .absent:
            result.checks.append(check("key", analysis.key == nil, "Expected no stable key."))
        case .labelled:
            result.checks.append(check("key", analysis.key == expected.key.key,
                "Exact tonic and mode required; relative keys and adjacent fifths receive no equivalence credit."))
        }
        switch expected.downbeat.status {
        case .unlabelled:
            result.checks.append(.init(metric: "downbeat", outcome: .unlabelled, detail: "No reference bar annotation."))
        case .absent:
            result.checks.append(check("downbeat", analysis.detectedDownbeatOffset == nil, "Expected no automatic downbeat."))
        case .labelled:
            if let offset = analysis.detectedDownbeatOffset, (0..<4).contains(offset),
               let bpm = analysis.bpm, bpm.isFinite, bpm > 0, let anchor = result.beatAnchorSeconds, anchor.isFinite,
               let expectedBPM = expected.tempo.bpm, let expectedBar = expected.downbeat.barStartSeconds,
               expectedBar < analysis.duration,
               expected.downbeat.barTimesSeconds?.last.map({ $0 < analysis.duration }) ?? true {
                let period = 60 / bpm
                let expectedBarPeriod = 4 * 60 / expectedBPM
                let detectedBar = anchor + Double(offset) * period
                let firstBar = ((expectedBar - detectedBar) / (4 * period)).rounded()
                let phase = detectedBar + firstBar * 4 * period - expectedBar
                let lastBar = floor((analysis.duration - 1 / analysis.sampleRate - expectedBar) / expectedBarPeriod)
                let error: Double
                if let times = expected.downbeat.barTimesSeconds {
                    error = times.enumerated().map { index, time in
                        abs(detectedBar + (firstBar + Double(index)) * 4 * period - time) * 1000
                    }.max() ?? .infinity
                } else { error = max(abs(phase), abs(phase + lastBar * (4 * period - expectedBarPeriod))) * 1000 }
                result.checks.append(check("downbeat", error <= limits.maximumDownbeatErrorMilliseconds,
                    "Automatic bar alignment across the file. Manual preparation and a default zero offset are excluded.",
                    error: error, limit: limits.maximumDownbeatErrorMilliseconds))
            } else {
                result.checks.append(check("downbeat", false, "No valid automatic downbeat. A beat anchor alone does not identify beat one."))
            }
        }
        return result
    }

    static func report(manifest: AnalysisBenchmarkManifest, measurements: [AnalysisBenchmarkMeasurement]) -> AnalysisBenchmarkReport {
        var blockers: [String] = []
        if manifest.corpus != .tdj1Reference { blockers.append("Synthetic diagnostics cannot establish real-music or TDJ1 parity.") }
        if manifest.referenceBuild != "1.6.8.67" { blockers.append("Paired annotations for the required TDJ1 build 1.6.8.67 are missing.") }
        if manifest.tracks.isEmpty { blockers.append("No annotated tracks.") }
        let tags = Set(manifest.tracks.flatMap(\.tags))
        let requiredTags = Set(manifest.requiredTags + (manifest.corpus == .tdj1Reference ? requiredReferenceTags : []))
        for tag in requiredTags.sorted() where !tags.contains(tag) { blockers.append("Missing corpus coverage: " + tag) }
        if measurements.count != manifest.tracks.count || Set(measurements.map(\.id)) != Set(manifest.tracks.map(\.id)) {
            blockers.append("Not every annotated track produced exactly one result.")
        }
        if measurements.contains(where: { $0.checks.contains { $0.outcome == .unlabelled } }) {
            blockers.append("Unlabelled dimensions remain; they are not counted as successful detections.")
        }
        for metric in ["tempo", "key", "downbeat"] {
            let hasPositiveLabel = manifest.tracks.contains {
                switch metric {
                case "tempo": return $0.tempo.status == .labelled
                case "key": return $0.key.status == .labelled
                default: return $0.downbeat.status == .labelled
                }
            }
            if !hasPositiveLabel { blockers.append("No positive labelled examples for " + metric + ".") }
        }
        let byID = Dictionary(measurements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var energyChecks: [AnalysisBenchmarkCheck] = []
        for pair in manifest.energyComparisons {
            let metric = "energy:" + pair.firstTrackID + ":" + pair.secondTrackID
            guard let firstResult = byID[pair.firstTrackID], let secondResult = byID[pair.secondTrackID],
                  firstResult.checks.contains(where: { $0.metric == "source" && $0.outcome == .pass }),
                  secondResult.checks.contains(where: { $0.metric == "source" && $0.outcome == .pass }),
                  let first = firstResult.energyLevel, let second = secondResult.energyLevel else {
                energyChecks.append(.init(metric: metric, outcome: .fail, detail: "Energy unavailable or source identity failed."))
                continue
            }
            let distance = first - second
            let pass: Bool
            switch pair.relation {
            case .lower: pass = distance < 0
            case .similar: pass = abs(distance) <= manifest.limits.maximumSimilarEnergyDistance
            case .higher: pass = distance > 0
            }
            energyChecks.append(.init(metric: metric, outcome: pass ? .pass : .fail,
                detail: "Expected \(pair.relation.rawValue); levels \(first) and \(second). " + pair.annotation,
                error: Double(abs(distance)), limit: pair.relation == .similar ? Double(manifest.limits.maximumSimilarEnergyDistance) : nil))
        }
        if energyChecks.isEmpty { blockers.append("No annotated energy comparisons.") }
        if manifest.corpus == .tdj1Reference {
            if !manifest.energyComparisons.contains(where: { $0.relation == .similar }) {
                blockers.append("No similar-energy comparisons, including gain/mastering variants.")
            }
            if !manifest.energyComparisons.contains(where: { $0.relation != .similar }) {
                blockers.append("No energy ordering comparisons.")
            }
            if !manifest.tracks.contains(where: { $0.tags.contains("tempo-drift") && $0.tempo.beatTimesSeconds != nil && $0.downbeat.barTimesSeconds != nil }) {
                blockers.append("No consecutive beat/bar annotations for music with tempo drift.")
            }
        }
        let allChecks = measurements.flatMap(\.checks) + energyChecks
        let labelledPassed = !allChecks.isEmpty && !allChecks.contains { $0.outcome == .fail }
        if !labelledPassed { blockers.append("One or more measured checks failed.") }
        return .init(manifest: manifest, corpus: manifest.corpus, referenceBuild: manifest.referenceBuild, limits: manifest.limits,
            tracks: measurements, energyChecks: energyChecks, blockers: blockers,
            labelledChecksPassed: labelledPassed, referenceCorpusPassed: blockers.isEmpty)
    }
}
