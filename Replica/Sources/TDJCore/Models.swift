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
        ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][tonic]
        + (mode == .minor ? "m" : "")
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
    public let implementation: String
    public let configurationID: String
    public let contentSHA256: String
    public let sampleRate: Double
    public let frameCount: Int64
    public let channelCount: Int
    public let waveformFramesPerBin: Int
    public let waveform: [WaveformBin]
    public let bpm: Double?
    public let beatAnchorFrame: Double?
    public let tempoConfidence: Double
    public let key: MusicalKey?
    public let keyConfidence: Double
    public let chroma: [Double]
    public let timbre: [Double]
    public var musicalAnalysisDeferred: Bool? = nil
    public var waveformReference: String? = nil
    public var cachedEnergyLevel: Int? = nil
    public var detectedDownbeatOffset: Int? = nil
    public var downbeatConfidence: Double? = nil
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
        var copy = AudioAnalysis(implementation:implementation,configurationID:configurationID,
            contentSHA256:contentSHA256,sampleRate:sampleRate,frameCount:frameCount,channelCount:channelCount,
            waveformFramesPerBin:waveformFramesPerBin,waveform:bins,bpm:bpm,beatAnchorFrame:beatAnchorFrame,
            tempoConfidence:tempoConfidence,key:key,keyConfidence:keyConfidence,chroma:chroma,timbre:timbre)
        copy.musicalAnalysisDeferred = musicalAnalysisDeferred
        copy.waveformReference = waveformReference
        copy.cachedEnergyLevel = cachedEnergyLevel
        copy.detectedDownbeatOffset = detectedDownbeatOffset
        copy.downbeatConfidence = downbeatConfidence
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
    public var correctedKey: MusicalKey?
    public var gridIsManual: Bool
    public var adaptiveMap: BeatGridMap? = nil
    public var gridLocked = false
    public var gridMode: GridMode = .automatic
    private enum CodingKeys: String, CodingKey { case grid, correctedKey, gridIsManual, adaptiveMap, gridLocked, gridMode }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grid = try c.decodeIfPresent(BeatGrid.self, forKey: .grid)
        correctedKey = try c.decodeIfPresent(MusicalKey.self, forKey: .correctedKey)
        gridIsManual = try c.decodeIfPresent(Bool.self, forKey: .gridIsManual) ?? false
        adaptiveMap = try? c.decodeIfPresent(BeatGridMap.self, forKey: .adaptiveMap)
        gridLocked = try c.decodeIfPresent(Bool.self, forKey: .gridLocked) ?? false
        gridMode = try c.decodeIfPresent(GridMode.self, forKey: .gridMode) ?? .automatic
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
    public var musicLibrarySources: [MusicLibrarySource]?
    public var nativeLibraryOnly: Bool? = nil
    public var bpm: Double? { grid?.bpm ?? analysis.bpm }
    public var key: MusicalKey? { preparation.correctedKey ?? traktorPreparation?.normalized.key ?? analysis.key }
    public var adaptiveMap: BeatGridMap? { preparation.adaptiveMap ?? analysis.adaptiveCandidate }
    public var grid: BeatGrid? {
        if preparation.gridIsManual { return preparation.grid }
        return traktorPreparation?.normalized.grid ?? preparation.grid
    }
    public init(title: String, artist: String = "", genre: String? = nil,
                mediaFilename: String, analysis: AudioAnalysis) throws {
        id = analysis.contentSHA256
        self.title = title
        self.artist = artist
        self.genre = genre
        self.mediaFilename = mediaFilename
        self.analysis = analysis
        let grid = try analysis.bpm.map {
            try BeatGrid(bpm: $0, anchorFrame: analysis.beatAnchorFrame ?? 0,
                         sampleRate: analysis.sampleRate, downbeatOffset: analysis.detectedDownbeatOffset ?? 0)
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
        lhs.schemaVersion == rhs.schemaVersion && lhs.revision == rhs.revision &&
            lhs.tracks == rhs.tracks && lhs.events == rhs.events &&
            lhs.adaptiveMemory == rhs.adaptiveMemory && lhs.calibration == rhs.calibration
    }
}
