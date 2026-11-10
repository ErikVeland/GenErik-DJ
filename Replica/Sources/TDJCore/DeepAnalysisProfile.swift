import CryptoKit
import Foundation

public struct AnalysisAudioIdentity: Codable, Equatable, Sendable {
    public let sha256: String
    public let sampleRate: Double
    public let frameCount: Int64
    public let channels: Int

    public init(_ analysis: AudioAnalysis) {
        sha256 = analysis.contentSHA256
        sampleRate = analysis.sampleRate
        frameCount = analysis.frameCount
        channels = analysis.channelCount
    }

    var key: String { analysisDigest(Data("\(sha256)|\(sampleRate.bitPattern)|\(frameCount)|\(channels)".utf8)) }
}

/// Versions describe evidence and decisions separately so policy changes can reuse predictions.
public struct DeepAnalysisProfile: Codable, Equatable, Sendable {
    public let generation: Int
    public let model: String
    public let weightsSHA256: String
    public let conversion: Int
    public let preprocessing: Int
    public let decisionPolicy: Int
    public let upgradeBenefit: String
    public var keyModelVersion: String? = nil

    public static let current = Self(
        generation: 10, model: "BeatThis/final0",
        weightsSHA256:
            "8c328b45f59d8dd3dff219253ff6a8d6482be57d0133a29140e2febbf8eb8331",
        conversion: 1, preprocessing: 1, decisionPolicy: 10,
        upgradeBenefit: "Refine review timing and retain rhythm reliability evidence.",
        keyModelVersion: LearnedKeyProfile.current.id)

    public var inferenceID: String {
        analysisDigest(Data("\(model)|\(weightsSHA256)|fp16-\(conversion)|mel-\(preprocessing)|1500-6-50".utf8))
    }

    public var id: String { "\(inferenceID)-policy\(decisionPolicy)" + (keyModelVersion.map { "-key-" + analysisDigest(Data($0.utf8)) } ?? "") }

    public func needsAnalysis(after result: DeepBeatAnalysis?) -> Bool {
        guard let result else { return true }
        if result.profile.id == id { return false }
        if generation == 7, decisionPolicy == 7,
            (result.profile.generation == 3 && result.profile.decisionPolicy == 3
                || result.profile.generation == 4 && result.profile.decisionPolicy == 4
                || result.profile.generation == 5 && result.profile.decisionPolicy == 5
                || result.profile.generation == 6 && result.profile.decisionPolicy == 6),
            inferenceID == result.profile.inferenceID
        {
            if result.profile.decisionPolicy >= 5 { return false }
            if result.hasStrongEvidence { return false }
            if result.profile.decisionPolicy == 4, result.candidate == nil { return false }
        }
        return generation > result.profile.generation && !upgradeBenefit.isEmpty
    }
}

public struct DeepBeatCandidate: Codable, Equatable, Sendable {
    public let bpm: Double
    public let firstBarSeconds: Double
    public let beatAgreement: Double
    public let barAgreement: Double
    public let residualMilliseconds: Double

    init(_ grid: BeatThisGrid) {
        bpm = grid.bpm
        firstBarSeconds = grid.firstBar
        beatAgreement = grid.beatAgreement
        barAgreement = grid.barAgreement
        residualMilliseconds = grid.residualMilliseconds
    }

    var isValid: Bool {
        bpm.isFinite && (20...400).contains(bpm) && firstBarSeconds.isFinite && firstBarSeconds >= 0
            && beatAgreement.isFinite && (0...1).contains(beatAgreement)
            && barAgreement.isFinite && (0...1).contains(barAgreement)
            && residualMilliseconds.isFinite && residualMilliseconds >= 0
    }

    var hasStrongEvidence: Bool {
        beatAgreement >= 0.90 && barAgreement >= 0.80 && residualMilliseconds <= 20
    }
}

public struct DeepBeatAnalysis: Codable, Equatable, Sendable {
    public let audio: AnalysisAudioIdentity
    public let profile: DeepAnalysisProfile
    public let coveredFrames: Int64
    public let windowCount: Int
    public let candidate: DeepBeatCandidate?
    public var tempoCandidateBPM: Double? = nil
    public var adaptiveCandidate: DeepAdaptiveBeatCandidate? = nil
    public var learnedKey: LearnedKeyAnalysis? = nil
    public var rhythmEvidence: DeepRhythmEvidence? = nil

    public var needsReview: Bool { adaptiveCandidate != nil || candidate == nil || !hasStrongEvidence }
    public func needsReview(for track: Track) -> Bool {
        guard track.mayRefreshAutomaticGrid, track.traktorPreparation?.normalized.grid == nil else { return false }
        return track.grid == nil || needsReview || compatibleGrid(for: track) == nil
    }
    var hasStrongEvidence: Bool { candidate?.hasStrongEvidence == true }

    public func validate(matching analysis: AudioAnalysis) throws {
        try rhythmEvidence?.validate()
        guard audio == AnalysisAudioIdentity(analysis), coveredFrames == audio.frameCount,
            audio.sampleRate.isFinite, audio.sampleRate > 0, audio.frameCount > 0, audio.channels > 0,
            BeatThisWindows.frameCount(analysis) > 0,
            windowCount == BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(analysis)).count,
            profile.generation > 0, profile.conversion > 0, profile.preprocessing > 0, profile.decisionPolicy > 0,
            profile.weightsSHA256.count == 64, profile.weightsSHA256.allSatisfy(\.isHexDigit),
            profile.model.utf8.count <= 128, profile.upgradeBenefit.utf8.count <= 1024,
            candidate.map({ $0.isValid && $0.firstBarSeconds < analysis.duration }) ?? true,
            tempoCandidateBPM.map({ $0.isFinite && (60...200).contains($0) && candidate == nil }) ?? true
        else { throw CoreError.invalidAudio("The deep analysis does not match this audio or its coverage.") }
        if let learnedKey {
            try learnedKey.validate()
            guard learnedKey.featureFrames == Int((Double(audio.frameCount) * 44100 / audio.sampleRate).rounded()) / 8820 - 1 else {
                throw CoreError.invalidAudio("The learned key coverage does not match this audio.")
            }
            guard profile.keyModelVersion == learnedKey.profile.id else {
                throw CoreError.invalidAudio("The learned key profile does not match the deep result.")
            }
        }
        if let adaptiveCandidate {
            try adaptiveCandidate.validate(frameCount: audio.frameCount, sampleRate: audio.sampleRate)
        }
    }

    /// A constant map can be reviewed through the same controls as a variable-tempo candidate.
    public var fixedReviewCandidate: BeatGridMap? {
        guard hasStrongEvidence, let candidate else { return nil }
        let map = BeatGridMap(anchors: [
            .init(beat: 0, frame: candidate.firstBarSeconds * audio.sampleRate),
            .init(beat: 1, frame: (candidate.firstBarSeconds + 60 / candidate.bpm) * audio.sampleRate),
        ], sampleRate: audio.sampleRate)
        return (try? map.validate(frameCount: audio.frameCount)) == nil ? nil : map
    }

    private func compatibleGrid(for track: Track) -> BeatGrid? {
        guard profile == .current, hasStrongEvidence, let candidate, track.mayRefreshAutomaticGrid,
            track.traktorPreparation?.normalized.grid == nil, (try? validate(matching: track.analysis)) != nil
        else { return nil }
        if let previous = track.grid {
            let period = 60 / candidate.bpm
            let priorBar =
                previous.anchorFrame / previous.sampleRate + Double(previous.downbeatOffset) * 60 / previous.bpm
            let time = candidate.firstBarSeconds - priorBar
            let phaseError = abs(time - (time / (4 * period)).rounded() * (4 * period))
            guard abs(candidate.bpm / previous.bpm - 1) <= 0.01, phaseError <= 0.04 else { return nil }
        }
        return try? BeatGrid(
            bpm: candidate.bpm, anchorFrame: candidate.firstBarSeconds * track.analysis.sampleRate,
            sampleRate: track.analysis.sampleRate, downbeatOffset: 0)
    }

    func acceptedTempoGrid(for track: Track) -> BeatGrid? {
        guard profile == .current, candidate == nil, let tempo = tempoCandidateBPM,
            track.mayRefreshAutomaticGrid, track.traktorPreparation?.normalized.grid == nil,
            track.analysis.acceptedDeepBeatAnalysis == nil, track.analysis.adaptiveCandidate == nil,
            track.analysis.implementation == "Beat This small0 with DSP grid fallback",
            (try? validate(matching: track.analysis)) != nil, let previous = track.grid,
            let factor = [0.5, 2.0].first(where: { abs(tempo / (previous.bpm * $0) - 1) <= 0.01 })
        else { return nil }
        // Keep the measured pulse precision. This changes its octave, not its phase.
        return try? BeatGrid(
            bpm: previous.bpm * factor, anchorFrame: previous.anchorFrame,
            sampleRate: previous.sampleRate, downbeatOffset: 0)
    }
}

enum BeatThisWindows {
    static let size = 1500
    static let border = 6
    static func frameCount(_ analysis: AudioAnalysis) -> Int {
        let samples = (Double(analysis.frameCount) * 22050 / analysis.sampleRate).rounded()
        guard samples.isFinite, samples >= 2, samples <= 24 * 3600 * 22050 else { return 0 }
        return Int(samples) / 441 + 1
    }
    static func starts(frameCount: Int) -> [Int] {
        let step = size - 2 * border
        var starts = Array(stride(from: -border, to: frameCount - border, by: step))
        if frameCount > step { starts[starts.count - 1] = frameCount - size + border }
        return starts
    }
}

func analysisDigest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension Track {
    public func adoptingDeepAnalysis(_ result: DeepBeatAnalysis) throws -> Track {
        try result.validate(matching: analysis)
        guard CloudPreparationArchive.hasAudioIdentity(self), result.profile == .current,
            DeepAnalysisProfile.current.needsAnalysis(after: analysis.deepBeatAnalysis)
        else { return self }
        var copy = self
        if let grid = result.acceptedTempoGrid(for: self) {
            copy.analysis.implementation = "\(result.profile.model) tempo octave with DSP beat phase"
            copy.analysis.acceptedDeepBeatAnalysis = result
            copy.preparation.grid = grid
            copy.analysis.bpm = grid.bpm
            copy.analysis.beatAnchorFrame = grid.anchorFrame
            copy.analysis.tempoConfidence = min(analysis.tempoConfidence, 0.69)
            copy.analysis.detectedDownbeatOffset = nil
            copy.analysis.downbeatConfidence = nil
            copy.analysis.gridResidualMilliseconds = nil
            copy.analysis.beatModelVersion = result.profile.id
            copy.analysis.barAnalysisVersion = BarStartAnalysis.version
            copy.analysis.musicalAnalysisDeferred = false
        }
        let reviewMap = result.adaptiveCandidate?.map ?? (grid == nil ? result.fixedReviewCandidate : nil)
        let previousReview = analysis.deepBeatAnalysis?.adaptiveCandidate?.map ?? analysis.deepBeatAnalysis?.fixedReviewCandidate
        let mayReplaceReview = analysis.adaptiveCandidate == nil
            || (previousReview != nil && analysis.adaptiveCandidate == previousReview)
        if let reviewMap, mayRefreshAutomaticGrid,
            traktorPreparation?.normalized.grid == nil, mayReplaceReview
        {
            copy.analysis.adaptiveCandidate = reviewMap
            copy.analysis.adaptiveConfidence = result.rhythmConfidence?.probability
        }
        if let learned = result.learnedKey, learned.mayReplaceAutomaticKey,
            keyDecision.authority == nil || keyDecision.authority == .independent || keyDecision.authority == .unknownTag
        {
            copy.analysis.acceptedLearnedKey = learned
            copy.analysis.key = learned.key
            copy.analysis.keyConfidence = learned.calibratedConfidence ?? learned.score
        }
        copy.analysis.deepBeatAnalysis = result
        copy.recordKeyAnalysisChange(from: analysis)
        return copy
    }
}

extension AudioAnalysis {
    func retainingDeepEvidence(from previous: AudioAnalysis) -> Self {
        guard AnalysisAudioIdentity(self) == AnalysisAudioIdentity(previous) else { return self }
        var copy = self
        copy.deepBeatAnalysis = previous.deepBeatAnalysis
        copy.acceptedDeepBeatAnalysis = previous.acceptedDeepBeatAnalysis
        copy.acceptedLearnedKey = previous.acceptedLearnedKey
            ?? previous.deepBeatAnalysis?.learnedKey.flatMap {
                $0.mayReplaceAutomaticKey && previous.key == $0.key ? $0 : nil
            }
        if let learned = copy.acceptedLearnedKey, previous.key == learned.key
        {
            copy.key = previous.key
            copy.keyConfidence = previous.keyConfidence
        }
        if let candidate = previous.deepBeatAnalysis?.adaptiveCandidate?.map
            ?? previous.deepBeatAnalysis?.fixedReviewCandidate,
            previous.adaptiveCandidate == candidate
        {
            copy.adaptiveCandidate = candidate
            copy.adaptiveConfidence = previous.deepBeatAnalysis?.rhythmConfidence?.probability
        }
        if previous.acceptedDeepBeatAnalysis != nil {
            copy.implementation = previous.implementation
            copy.bpm = previous.bpm
            copy.beatAnchorFrame = previous.beatAnchorFrame
            copy.tempoConfidence = previous.tempoConfidence
            copy.detectedDownbeatOffset = previous.detectedDownbeatOffset
            copy.downbeatConfidence = previous.downbeatConfidence
            copy.gridResidualMilliseconds = previous.gridResidualMilliseconds
            copy.barAnalysisVersion = previous.barAnalysisVersion
            copy.beatModelVersion = previous.beatModelVersion
            copy.musicalAnalysisDeferred = false
        }
        return copy
    }
}
