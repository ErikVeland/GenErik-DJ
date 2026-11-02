import Foundation

public struct PerformanceEvent: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case load, preview, transition, recordingFinished }
    public let id: UUID
    public let sessionID: UUID
    public let kind: Kind
    public let timestamp: Date
    public let fromTrackID: String?
    public let toTrackID: String?
    public let durationSeconds: Double?
    public init(id: UUID = UUID(), sessionID: UUID, kind: Kind, timestamp: Date,
                fromTrackID: String?, toTrackID: String?, durationSeconds: Double? = nil) {
        self.id = id; self.sessionID = sessionID; self.kind = kind; self.timestamp = timestamp
        self.fromTrackID = fromTrackID; self.toTrackID = toTrackID; self.durationSeconds = durationSeconds
    }
}

public struct SuggestionCalibration: Codable, Equatable, Sendable {
    public enum Basis: String, Codable, Sendable { case syntheticDevelopment, originalReference }
    public enum TieOrder: String, Codable, Sendable { case libraryOrder, trackID }
    public struct Weights: Codable, Equatable, Sendable {
        public let tempo: Double
        public let key: Double
        public let timbre: Double
        public let genre: Double
        public let history: Double
        var values: [Double] { [tempo, key, timbre, genre, history] }
    }
    public struct KeyRelation: Codable, Equatable, Sendable {
        public let from: MusicalKey
        public let to: MusicalKey
        public let score: Double
    }
    public let id: String
    public let basis: Basis
    public let referenceCaseIDs: [String]
    public let weights: Weights
    public let tempoRatios: [Double]
    public let tempoDistanceScale: Double
    public let tempoCompatibilityDistance: Double
    public let keyRelations: [KeyRelation]
    public let keyCompatibilityScore: Double
    public let timbreDistanceScale: Double
    public let genreCaseInsensitive: Bool
    public let learningEventWeights: [String: Double]
    public let minimumTransitionDurationSeconds: Double?
    public let symmetricTransitions: Bool
    public let historySaturation: Double
    public let excludeReferenceTrack: Bool
    public let excludeLoadedTracks: Bool
    public let tieOrder: TieOrder

    public func validate() throws {
        let nonnegative = weights.values + Array(learningEventWeights.values) + [tempoCompatibilityDistance, keyCompatibilityScore]
        guard !id.isEmpty, nonnegative.allSatisfy({ $0.isFinite && $0 >= 0 }),
              weights.values.reduce(0, +).isFinite, weights.values.reduce(0, +) > 0,
              [tempoDistanceScale, timbreDistanceScale, historySaturation].allSatisfy({ $0.isFinite && $0 > 0 }),
              !tempoRatios.isEmpty, tempoRatios.allSatisfy({ $0.isFinite && $0 > 0 }),
              keyCompatibilityScore <= 1,
              keyRelations.allSatisfy({ $0.score.isFinite && (0...1).contains($0.score) }),
              learningEventWeights.keys.allSatisfy({ PerformanceEvent.Kind(rawValue: $0) != nil }),
              minimumTransitionDurationSeconds.map({ $0.isFinite && $0 >= 0 }) ?? true,
              basis != .originalReference || !referenceCaseIDs.isEmpty
        else { throw CoreError.invalidCalibration("Required values or reference provenance are missing.") }
    }
}

public struct AdaptiveMemory: Codable, Equatable, Sendable {
    public private(set) var calibrationID: String?
    public private(set) var revision = 0
    private var pairs: [String: [String: Double]] = [:]
    private var appliedEventIDs: Set<UUID> = []
    public init() {}
    public func strength(from: String, to: String) -> Double { pairs[from]?[to] ?? 0 }

    public mutating func consume(_ event: PerformanceEvent, calibration: SuggestionCalibration) throws {
        try calibration.validate()
        guard calibrationID == nil || calibrationID == calibration.id else {
            throw CoreError.invalidCalibration("Rebuild memory from retained events when calibration changes.")
        }
        guard !appliedEventIDs.contains(event.id) else { return }
        calibrationID = calibration.id
        appliedEventIDs.insert(event.id)
        guard let weight = calibration.learningEventWeights[event.kind.rawValue], weight > 0,
              let from = event.fromTrackID, let to = event.toTrackID, from != to else { return }
        if let minimum = calibration.minimumTransitionDurationSeconds, event.kind == .transition {
            guard let duration = event.durationSeconds, duration.isFinite, duration >= minimum else { return }
        }
        pairs[from, default: [:]][to, default: 0] += weight
        if calibration.symmetricTransitions { pairs[to, default: [:]][from, default: 0] += weight }
        revision += 1
    }

    public static func rebuild(events: [PerformanceEvent], calibration: SuggestionCalibration) throws -> Self {
        var memory = Self()
        for event in events { try memory.consume(event, calibration: calibration) }
        return memory
    }
}

public struct SuggestionContext: Codable, Equatable, Sendable {
    public let referenceTrackID: String
    public let destination: DeckID
    public let performanceBPM: Double?
    public let usePerformanceBPM: Bool
    public let loadedTrackIDs: Set<String>
    public let libraryRevision: Int
    public let historyRevision: Int
    public init(referenceTrackID: String, destination: DeckID, performanceBPM: Double? = nil,
                usePerformanceBPM: Bool, loadedTrackIDs: Set<String>, libraryRevision: Int, historyRevision: Int) {
        self.referenceTrackID = referenceTrackID; self.destination = destination
        self.performanceBPM = performanceBPM; self.usePerformanceBPM = usePerformanceBPM
        self.loadedTrackIDs = loadedTrackIDs; self.libraryRevision = libraryRevision; self.historyRevision = historyRevision
    }
}

public struct Suggestion: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let score: Double
    public let tempoCompatible: Bool?
    public let keyCompatible: Bool?
}

/// A calibratable reconstruction model. No ranking or learning policy is supplied by default.
public enum SuggestionEngine {
    public static func rank(library: LibrarySnapshot, context: SuggestionContext,
                            calibration: SuggestionCalibration?) throws -> [Suggestion] {
        guard let calibration else { throw CoreError.calibrationRequired }
        try calibration.validate()
        guard context.libraryRevision == library.revision,
              context.historyRevision == library.adaptiveMemory.revision,
              let reference = library.tracks.first(where: { $0.id == context.referenceTrackID }) else {
            throw CoreError.staleContext
        }
        guard library.adaptiveMemory.calibrationID == nil || library.adaptiveMemory.calibrationID == calibration.id else {
            throw CoreError.invalidCalibration("History belongs to a different calibration.")
        }
        let referenceBPM = context.usePerformanceBPM ? context.performanceBPM : reference.bpm
        var results: [(Int, Suggestion)] = []
        for (index, track) in library.tracks.enumerated() {
            if calibration.excludeReferenceTrack && track.id == reference.id { continue }
            if calibration.excludeLoadedTracks && context.loadedTrackIDs.contains(track.id) { continue }
            var weighted = 0.0, totalWeight = 0.0
            func add(_ score: Double?, weight: Double) {
                guard let score, score.isFinite, weight > 0 else { return }
                weighted += max(0, min(1, score)) * weight; totalWeight += weight
            }
            var distance: Double?
            if let a = referenceBPM, let b = track.bpm, a > 0, b > 0 {
                distance = calibration.tempoRatios.map { abs(b * $0 - a) / a }.min()
            }
            add(distance.map { 1 - $0 / calibration.tempoDistanceScale }, weight: calibration.weights.tempo)
            let keyScore = calibration.keyRelations.first { $0.from == reference.key && $0.to == track.key }?.score
            add(keyScore, weight: calibration.weights.key)
            if reference.analysis.timbre.count == track.analysis.timbre.count, !track.analysis.timbre.isEmpty {
                let squares = zip(reference.analysis.timbre, track.analysis.timbre).map { pow($0 - $1, 2) }
                add(1 - sqrt(squares.reduce(0, +)) / calibration.timbreDistanceScale, weight: calibration.weights.timbre)
            }
            if let a = reference.genre, let b = track.genre, !a.isEmpty, !b.isEmpty {
                let equal = calibration.genreCaseInsensitive ? a.caseInsensitiveCompare(b) == .orderedSame : a == b
                add(equal ? 1 : 0, weight: calibration.weights.genre)
            }
            let history = library.adaptiveMemory.strength(from: reference.id, to: track.id)
            add(history / (history + calibration.historySaturation), weight: calibration.weights.history)
            guard totalWeight > 0 else { continue }
            results.append((index, Suggestion(id: track.id, score: weighted / totalWeight,
                tempoCompatible: distance.map { $0 <= calibration.tempoCompatibilityDistance },
                keyCompatible: keyScore.map { $0 >= calibration.keyCompatibilityScore })))
        }
        return results.sorted { a, b in
            if a.1.score != b.1.score { return a.1.score > b.1.score }
            return calibration.tieOrder == .libraryOrder ? a.0 < b.0 : a.1.id < b.1.id
        }.map(\.1)
    }
}
