import Foundation

public enum CoreError: Error, LocalizedError, Equatable {
    case invalidAudio(String)
    case invalidGrid
    case insufficientTaps
    case calibrationRequired
    case invalidCalibration(String)
    case staleContext
    case invalidWorkspace(String)
    public var errorDescription: String? {
        switch self {
        case .invalidAudio(let message): return message
        case .invalidGrid: return "The grid needs a finite positive BPM and sample rate."
        case .insufficientTaps: return "Tap at least three times at increasing times."
        case .calibrationRequired: return "Original suggestion ranking has not been calibrated."
        case .invalidCalibration(let message): return "Invalid calibration: \(message)"
        case .staleContext: return "The music or history changed. Reopen suggestions."
        case .invalidWorkspace(let message): return "Cannot read the development workspace: \(message)"
        }
    }
}

public struct MusicalKey: Codable, Equatable, Sendable, Hashable {
    public enum Mode: String, Codable, Sendable { case major, minor }
    public let tonic: Int
    public let mode: Mode
    public init(tonic: Int, mode: Mode) {
        self.tonic = ((tonic % 12) + 12) % 12
        self.mode = mode
    }
    private enum CodingKeys: String, CodingKey { case tonic, mode }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let tonic = try values.decode(Int.self, forKey: .tonic)
        guard (0..<12).contains(tonic) else { throw CoreError.invalidWorkspace("Invalid musical key.") }
        self.init(tonic: tonic, mode: try values.decode(Mode.self, forKey: .mode))
    }
    public var name: String {
        ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][tonic] + (mode == .minor ? "m" : "")
    }
    public var openKeyName: String {
        let relativeMajor = mode == .major ? tonic : (tonic + 3) % 12
        return "\((relativeMajor * 7) % 12 + 1)\(mode == .major ? "d" : "m")"
    }
}

public struct WaveformBin: Codable, Equatable, Sendable {
    public let minimum: Float
    public let maximum: Float
    public let rms: Float
}

public struct AudioAnalysis: Codable, Equatable, Sendable {
    public internal(set) var implementation: String
    public let configurationID: String
    public let contentSHA256: String
    public let sampleRate: Double
    public let frameCount: Int64
    public let channelCount: Int
    public let waveformFramesPerBin: Int
    public let waveform: [WaveformBin]
    public internal(set) var bpm: Double?
    public internal(set) var beatAnchorFrame: Double?
    public internal(set) var tempoConfidence: Double
    public let key: MusicalKey?
    public let keyConfidence: Double
    public let chroma: [Double]
    public let timbre: [Double]
    public var beatModelVersion: String? = nil
    public var deepBeatAnalysis: DeepBeatAnalysis? = nil
    public var acceptedDeepBeatAnalysis: DeepBeatAnalysis? = nil
    public var musicalAnalysisDeferred: Bool? = nil
    public var waveformReference: String? = nil
    public var waveformDecodedFrames: Int64? = nil
    public var cachedEnergyLevel: Int? = nil
    public var detectedDownbeatOffset: Int? = nil
    public var downbeatConfidence: Double? = nil
    public var barAnalysisVersion: Int? = nil
    public var musicalEnergy: MusicalEnergyAnalysis? = nil
    public var tuningCents: Double? = nil
    public var keyStability: Double? = nil
    public var adaptiveCandidate: BeatGridMap? = nil
    public var adaptiveConfidence: Double? = nil
    public var gridResidualMilliseconds: Double? = nil
    public var duration: Double { Double(frameCount) / sampleRate }
}

extension AudioAnalysis {
    public func replacingWaveform(_ bins: [WaveformBin]) -> AudioAnalysis {
        replacingWaveform(
            bins, configurationID: configurationID, frameCount: frameCount, decodedFrames: waveformDecodedFrames)
    }
    public func replacingWaveform(
        _ bins: [WaveformBin], configurationID: String, frameCount: Int64, decodedFrames: Int64?
    ) -> AudioAnalysis {
        var copy = AudioAnalysis(
            implementation: implementation, configurationID: configurationID, contentSHA256: contentSHA256,
            sampleRate: sampleRate, frameCount: frameCount, channelCount: channelCount,
            waveformFramesPerBin: waveformFramesPerBin, waveform: bins, bpm: bpm, beatAnchorFrame: beatAnchorFrame,
            tempoConfidence: tempoConfidence, key: key, keyConfidence: keyConfidence, chroma: chroma, timbre: timbre)
        copy.beatModelVersion = beatModelVersion
        copy.deepBeatAnalysis = frameCount == self.frameCount ? deepBeatAnalysis : nil
        copy.acceptedDeepBeatAnalysis = frameCount == self.frameCount ? acceptedDeepBeatAnalysis : nil
        copy.musicalAnalysisDeferred = musicalAnalysisDeferred
        copy.waveformReference = configurationID == self.configurationID ? waveformReference : nil
        copy.waveformDecodedFrames = decodedFrames
        copy.cachedEnergyLevel = cachedEnergyLevel
        copy.detectedDownbeatOffset = detectedDownbeatOffset
        copy.downbeatConfidence = downbeatConfidence
        copy.barAnalysisVersion = barAnalysisVersion
        copy.musicalEnergy = musicalEnergy
        copy.tuningCents = tuningCents
        copy.keyStability = keyStability
        copy.adaptiveCandidate = adaptiveCandidate
        copy.adaptiveConfidence = adaptiveConfidence
        copy.gridResidualMilliseconds = gridResidualMilliseconds
        return copy
    }
}

public struct Preparation: Codable, Equatable, Sendable {
    public var grid: BeatGrid?
    public var correctedKey: MusicalKey? { didSet { correctedKeyAuthority = nil } }
    public internal(set) var correctedKeyAuthority: KeyAuthority?
    public var gridIsManual: Bool
    public var gridWasEditedByUser: Bool? = nil
    public var adaptiveMap: BeatGridMap? = nil
    public var gridLocked = false
    public var gridMode: GridMode = .automatic
    /// Choose a detected bar grid only when the saved grid has no user edits.
    public func detectedBarGrid(analysis: AudioAnalysis, imported: BeatGrid?, importIsUnlocked: Bool) -> BeatGrid? {
        guard
            AutomaticGridPolicy.mayRefresh(
                isManual: gridIsManual, wasEditedByUser: gridWasEditedByUser == true, isLocked: gridLocked,
                hasAdaptiveMap: adaptiveMap != nil, current: grid, imported: imported,
                importIsUnlocked: importIsUnlocked), analysis.barAnalysisVersion == BarStartAnalysis.version,
            analysis.tempoConfidence >= 0.72, (analysis.downbeatConfidence ?? 0) >= (imported == nil ? 0.55 : 0.72),
            let bpm = analysis.bpm, let anchor = analysis.beatAnchorFrame, let bar = analysis.detectedDownbeatOffset
        else { return nil }
        if let imported {
            let ratio = bpm / imported.bpm
            guard [0.5, 1.0, 2.0].contains(where: { abs(ratio / $0 - 1) <= 0.01 }) else { return nil }
        }
        return try? BeatGrid(bpm: bpm, anchorFrame: anchor, sampleRate: analysis.sampleRate, downbeatOffset: bar)
    }
    private enum CodingKeys: String, CodingKey {
        case grid, correctedKey, correctedKeyAuthority, gridIsManual, gridWasEditedByUser, adaptiveMap, gridLocked,
            gridMode
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grid = try c.decodeIfPresent(BeatGrid.self, forKey: .grid)
        correctedKey = try c.decodeIfPresent(MusicalKey.self, forKey: .correctedKey)
        correctedKeyAuthority = try c.decodeIfPresent(KeyAuthority.self, forKey: .correctedKeyAuthority)
        guard
            correctedKeyAuthority == nil
                || (correctedKey != nil && [.traktor, .independent].contains(correctedKeyAuthority!))
        else { throw CoreError.invalidWorkspace("Invalid imported key authority.") }
        gridIsManual = try c.decodeIfPresent(Bool.self, forKey: .gridIsManual) ?? false
        gridWasEditedByUser = try c.decodeIfPresent(Bool.self, forKey: .gridWasEditedByUser)
        adaptiveMap = try? c.decodeIfPresent(BeatGridMap.self, forKey: .adaptiveMap)
        gridLocked = try c.decodeIfPresent(Bool.self, forKey: .gridLocked) ?? false
        gridMode = try c.decodeIfPresent(GridMode.self, forKey: .gridMode) ?? .automatic
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(grid, forKey: .grid)
        try c.encodeIfPresent(correctedKey, forKey: .correctedKey)
        try c.encodeIfPresent(correctedKeyAuthority, forKey: .correctedKeyAuthority)
        try c.encode(gridIsManual, forKey: .gridIsManual)
        try c.encodeIfPresent(gridWasEditedByUser, forKey: .gridWasEditedByUser)
        try c.encodeIfPresent(adaptiveMap, forKey: .adaptiveMap)
        if gridLocked { try c.encode(true, forKey: .gridLocked) }
        if gridMode != .automatic { try c.encode(gridMode, forKey: .gridMode) }
    }
    public init(grid: BeatGrid? = nil, correctedKey: MusicalKey? = nil, gridIsManual: Bool = false) {
        self.grid = grid
        self.correctedKey = correctedKey
        self.gridIsManual = gridIsManual
    }
}

public struct Track: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var artist: String
    public var genre: String?
    public var album: String?
    public var artworkFilename: String?
    public let mediaFilename: String
    public var analysis: AudioAnalysis
    public var preparation: Preparation
    public var traktorPreparation: ImportedTraktorPreparation? = nil
    public var keyGovernance: KeyGovernanceState? = nil
    public var musicLibrarySources: [MusicLibrarySource]?
    public var nativeLibraryOnly: Bool? = nil
    public var nativePlaybackIdentity: String? = nil
    var nativeAudioFingerprint: String? = nil
    public var nativeSourceNeedsAnalysis: Bool? = nil
    public var bpm: Double? { grid?.bpm ?? analysis.bpm }
    public var key: MusicalKey? { keyDecision.key }
    public var adaptiveMap: BeatGridMap? {
        guard preparation.gridMode != .fixed, let map = preparation.adaptiveMap, map.sampleRate == analysis.sampleRate,
            (try? map.validate(frameCount: analysis.frameCount)) != nil
        else { return nil }
        return map
    }
    public var timing: BeatTiming? { grid.map { BeatTiming(fixed: $0, adaptive: adaptiveMap) } }
    public var mayRefreshAutomaticGrid: Bool {
        AutomaticGridPolicy.mayRefresh(
            isManual: preparation.gridIsManual, wasEditedByUser: preparation.gridWasEditedByUser == true,
            isLocked: preparation.gridLocked, hasAdaptiveMap: preparation.adaptiveMap != nil, current: preparation.grid,
            imported: traktorPreparation?.normalized.grid,
            importIsUnlocked: traktorPreparation?.record.rawEntry.attributes["LOCK"] == "0")
    }
    public var needsAutomaticBarAnalysis: Bool {
        mayRefreshAutomaticGrid && analysis.barAnalysisVersion != BarStartAnalysis.version
    }
    var needsTempoOctaveUpgrade: Bool {
        mayRefreshAutomaticGrid && traktorPreparation?.normalized.grid == nil
            && !NativeAnalysisPlan.isMix(duration: analysis.duration)
            && analysis.beatModelVersion == "BeatThis/small0-6074be2c-mel1-fit1"
            && analysis.implementation == "Beat This small0 with DSP grid fallback"
    }
    var needsAdaptiveCandidateUpgrade: Bool {
        mayRefreshAutomaticGrid && traktorPreparation?.normalized.grid == nil
            && analysis.acceptedDeepBeatAnalysis == nil && analysis.adaptiveCandidate != nil
            && (analysis.configurationID.hasPrefix("beat-this-small0-grid-1-")
                || analysis.configurationID.hasPrefix("beat-this-small0-grid-2-"))
    }
    public var needsFullPreparationAnalysis: Bool {
        nativeSourceNeedsAnalysis == true || analysis.musicalAnalysisDeferred == true || needsAutomaticBarAnalysis
            || needsTempoOctaveUpgrade || needsAdaptiveCandidateUpgrade
            || (analysis.configurationID != AnalysisConfiguration().id(for: analysis.duration)
                && NativeAnalysisPlan.needsDeckAnalysis(deferred: nil, bpm: bpm, key: key))
    }
    public var needsCurrentLibraryAnalysis: Bool {
        if nativeSourceNeedsAnalysis == true || needsTempoOctaveUpgrade || needsAdaptiveCandidateUpgrade { return true }
        guard grid == nil || key == nil else { return false }
        return analysis.configurationID != AnalysisConfiguration().id(for: analysis.duration)
            || needsFullPreparationAnalysis
    }
    public var automaticBarGrid: BeatGrid? {
        preparation.detectedBarGrid(
            analysis: analysis, imported: traktorPreparation?.normalized.grid,
            importIsUnlocked: traktorPreparation?.record.rawEntry.attributes["LOCK"] == "0")
    }
    public var grid: BeatGrid? {
        if let automaticBarGrid { return automaticBarGrid }
        if preparation.gridIsManual || preparation.gridWasEditedByUser == true || preparation.gridLocked {
            return preparation.grid
        }
        return traktorPreparation?.normalized.grid ?? preparation.grid
    }
    public init(
        title: String, artist: String = "", genre: String? = nil, mediaFilename: String, analysis: AudioAnalysis
    ) throws {
        id = analysis.contentSHA256
        self.title = title
        self.artist = artist
        self.genre = genre
        self.mediaFilename = mediaFilename
        self.analysis = analysis
        let grid = try analysis.bpm.map {
            try BeatGrid(
                bpm: $0, anchorFrame: analysis.beatAnchorFrame ?? 0, sampleRate: analysis.sampleRate,
                downbeatOffset: analysis.detectedDownbeatOffset ?? 0)
        }
        preparation = Preparation(grid: grid)
    }
}

public enum DeckID: String, Codable, CaseIterable, Sendable { case a, b }

public struct LibrarySnapshot: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var revision = 0
    private var backingTracks: [Track] = []
    public var tracks: [Track] {
        _read { yield backingTracks }
        set {
            trackLookup = nil
            backingTracks = newValue
        }
        _modify {
            trackLookup = nil
            yield &backingTracks
        }
    }
    public var events: [PerformanceEvent] = []
    public var adaptiveMemory = AdaptiveMemory()
    public var calibration: SuggestionCalibration?
    private var trackLookup: LibraryTrackLookup?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, revision, events, adaptiveMemory, calibration
        case backingTracks = "tracks"
    }

    public init() {}

    public func track(id: String) -> Track? {
        if let trackLookup {
            guard let index = trackLookup.index(for: id) else { return nil }
            return tracks[index]
        }
        return tracks.first { $0.id == id }
    }

    func preparingTrackLookup() -> Self {
        guard trackLookup == nil else { return self }
        var prepared = self
        prepared.trackLookup = LibraryTrackLookup(tracks: tracks)
        return prepared
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.schemaVersion == rhs.schemaVersion && lhs.revision == rhs.revision && lhs.tracks == rhs.tracks
            && lhs.events == rhs.events && lhs.adaptiveMemory == rhs.adaptiveMemory
            && lhs.calibration == rhs.calibration
    }
}
