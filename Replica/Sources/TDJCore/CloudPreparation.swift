import CryptoKit
import Foundation

/// A complete preparation revision. Playback locations remain device-local.
public struct CloudPreparationArchive: Codable, Equatable, Sendable {
    public var version = 1
    public var automaticAnalysis: Bool? = nil
    public let track: Track
    public let cues: [Int: PerformanceCue]?
    public let cueHistory: TraktorPreparationImportHistory?
    public let sectionCuesPrepared: Bool
    public let gridCuesPrepared: Bool
    public let arrangement: Data?
    public let waveformData: Data?

    public init(track: Track, performance: PerformancePreparation, arrangement: Data?, waveformData: Data? = nil) {
        self.track = track
        cues = performance.cues[track.id]
        cueHistory = performance.traktorCueHistory?[track.id]
        sectionCuesPrepared = performance.sectionCueTracks?.contains(track.id) == true
        gridCuesPrepared = performance.gridCueTracks?.contains(track.id) == true
        self.arrangement = arrangement
        self.waveformData = waveformData
    }

    public func matches(_ local: Track) -> Bool {
        Self.hasAudioIdentity(local) && Self.hasAudioIdentity(track)
            && local.analysis.contentSHA256 == track.analysis.contentSHA256
            && local.analysis.sampleRate == track.analysis.sampleRate
            && local.analysis.frameCount == track.analysis.frameCount
            && local.analysis.channelCount == track.analysis.channelCount
    }

    public static func hasAudioIdentity(_ track: Track) -> Bool {
        !track.analysis.configurationID.hasPrefix("native-") && track.nativeSourceNeedsAnalysis != true
    }

    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else {
            throw Self.invalid("This preparation exceeds the cloud record size limit.")
        }
        return data
    }

    private enum CodingKeys: String, CodingKey {
        case version, automaticAnalysis, track, cues, cueHistory, sectionCuesPrepared, gridCuesPrepared, arrangement,
            waveformData
    }
    private enum HistoryKeys: String, CodingKey { case previouslyImportedSlots, protectedEmptySlots }
    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encodeIfPresent(automaticAnalysis, forKey: .automaticAnalysis)
        try values.encode(track, forKey: .track)
        try values.encodeIfPresent(cues, forKey: .cues)
        if let cueHistory {
            var history = values.nestedContainer(keyedBy: HistoryKeys.self, forKey: .cueHistory)
            try history.encode(cueHistory.previouslyImportedSlots.sorted(), forKey: .previouslyImportedSlots)
            try history.encode(cueHistory.protectedEmptySlots.sorted(), forKey: .protectedEmptySlots)
        }
        try values.encode(sectionCuesPrepared, forKey: .sectionCuesPrepared)
        try values.encode(gridCuesPrepared, forKey: .gridCuesPrepared)
        try values.encodeIfPresent(arrangement, forKey: .arrangement)
        try values.encodeIfPresent(waveformData, forKey: .waveformData)
    }

    public static let maximumBytes = 32 * 1024 * 1024
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw invalid("The cloud preparation is too large.") }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.validate()
        return value
    }

    private func validate() throws {
        guard (version == 1 && automaticAnalysis != true) || (version == 2 && automaticAnalysis == true),
            Self.hasAudioIdentity(track)
        else {
            throw Self.invalid("The cloud preparation has an unsupported version or an unverified audio identity.")
        }
        var snapshot = LibrarySnapshot()
        snapshot.tracks = [track]
        try WorkspaceStore.validate(snapshot)
        if let waveformData {
            guard track.analysis.waveformReference != nil else {
                throw Self.invalid("The cloud waveform reference is missing.")
            }
            _ = try WaveformStorage.decode(waveformData, analysis: track.analysis)
        } else if track.analysis.waveformReference != nil && track.analysis.waveform.isEmpty {
            throw Self.invalid("The cloud waveform data is missing.")
        }
        let end = Double(track.analysis.frameCount)
        guard
            (cues ?? [:]).allSatisfy({ slot, cue in
                (0..<8).contains(slot) && cue.frame.isFinite && cue.frame >= 0 && cue.frame < end
                    && (cue.loopEnd.map { $0.isFinite && $0 > cue.frame && $0 <= end } ?? true)
                    && (cue.category == .loop ? cue.loopEnd != nil : cue.loopEnd == nil)
            }),
            cueHistory.map({
                ($0.protectedEmptySlots.union($0.previouslyImportedSlots)).allSatisfy { (0..<8).contains($0) }
            }) ?? true
        else { throw Self.invalid("The cloud preparation contains invalid cues.") }
        if let arrangement {
            struct Structure: Decodable {
                let content: String
                let arrangement: TrackArrangement
            }
            let value = try JSONDecoder().decode(Structure.self, from: arrangement)
            guard value.content == track.analysis.contentSHA256, value.arrangement.isValid(fileEnd: end) else {
                throw Self.invalid("The cloud sections do not match the audio.")
            }
        }
    }

    static func invalid(_ message: String) -> CoreError { .invalidWorkspace(message) }

    public func restoredTrack(matching local: Track) throws -> Track {
        try validate()
        guard automaticAnalysis != true else {
            throw Self.invalid("Analysis-only revisions cannot replace full preparation.")
        }
        guard matches(local) else { throw Self.invalid("The cloud preparation does not match this audio file.") }
        var restored = local
        restored.analysis = track.analysis
        restored.preparation = track.preparation
        restored.traktorPreparation = track.traktorPreparation
        if local.id == track.id {
            restored.keyGovernance = track.keyGovernance
        } else {
            // Explicit recovery adopts the selected key. Original evidence stays in the archive.
            restored.keyGovernance = nil
            restored.preparation.correctedKey = track.key
        }
        restored.nativeSourceNeedsAnalysis = nil
        return restored
    }

    public func restoreCues(to performance: inout PerformancePreparation, trackID: String) {
        performance.cues[trackID] = cues
        if performance.traktorCueHistory == nil { performance.traktorCueHistory = [:] }
        performance.traktorCueHistory?[trackID] = cueHistory
        if performance.sectionCueTracks == nil { performance.sectionCueTracks = [] }
        if performance.gridCueTracks == nil { performance.gridCueTracks = [] }
        if sectionCuesPrepared {
            performance.sectionCueTracks?.insert(trackID)
        } else {
            performance.sectionCueTracks?.remove(trackID)
        }
        if gridCuesPrepared {
            performance.gridCueTracks?.insert(trackID)
        } else {
            performance.gridCueTracks?.remove(trackID)
        }
    }
}

public struct CloudPreparationVault: Sendable {
    public struct Revision: Codable, Identifiable, Sendable {
        public let id: String
        public let audioSHA256: String
        public let sourceTrackID: String
        public let title: String
        public let artist: String
        public let savedAt: Date
        public var automaticAnalysis: Bool? = nil
    }
    public let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    public func payloadURL(_ id: String) -> URL { root.appendingPathComponent(id + ".payload") }
    public func read(_ id: String) throws -> CloudPreparationArchive {
        guard KeyImportManifest.isDigest(id) else {
            throw CloudPreparationArchive.invalid("The cloud revision identifier is invalid.")
        }
        let url = payloadURL(id)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= CloudPreparationArchive.maximumBytes else {
            throw CloudPreparationArchive.invalid("The cloud preparation is too large.")
        }
        let data = try Data(contentsOf: url)
        guard Self.digest(data) == id else {
            throw CloudPreparationArchive.invalid("The saved cloud revision failed its integrity check.")
        }
        return try CloudPreparationArchive.decode(data)
    }
    @discardableResult public func retain(_ archive: CloudPreparationArchive, savedAt: Date = Date()) throws -> Revision
    {
        try retain(data: archive.encoded(), savedAt: savedAt)
    }
    @discardableResult public func retain(data: Data, expectedID: String? = nil, savedAt: Date = Date()) throws
        -> Revision
    {
        let archive = try CloudPreparationArchive.decode(data)
        let id = Self.digest(data)
        guard expectedID == nil || expectedID == id else {
            throw CloudPreparationArchive.invalid("The downloaded cloud revision failed its integrity check.")
        }
        let meta = root.appendingPathComponent(id + ".json")
        if FileManager.default.fileExists(atPath: meta.path) {
            _ = try read(id)
            return try JSONDecoder().decode(Revision.self, from: Data(contentsOf: meta))
        }
        try data.write(to: payloadURL(id), options: .atomic)
        var revision = Revision(
            id: id, audioSHA256: archive.track.analysis.contentSHA256,
            sourceTrackID: archive.track.id, title: archive.track.title, artist: archive.track.artist, savedAt: savedAt)
        revision.automaticAnalysis = archive.automaticAnalysis
        try JSONEncoder().encode(revision).write(to: meta, options: .atomic)
        return revision
    }
    public func list() throws -> [Revision] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter {
                $0.pathExtension == "json" && KeyImportManifest.isDigest($0.deletingPathExtension().lastPathComponent)
            }
            .map { try JSONDecoder().decode(Revision.self, from: Data(contentsOf: $0)) }
            .sorted { $0.savedAt > $1.savedAt }
    }
    public static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    public static func arrangementURL(root: URL, trackID: String) -> URL {
        let safeID = trackID.utf8.map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("Arrangements").appendingPathComponent(safeID + ".json")
    }

    public static func capture(store: WorkspaceStore, track: Track, performance: PerformancePreparation) throws
        -> CloudPreparationArchive
    {
        let arrangementURL = arrangementURL(root: store.root, trackID: track.id)
        let arrangement =
            FileManager.default.fileExists(atPath: arrangementURL.path) ? try Data(contentsOf: arrangementURL) : nil
        let waveform = try track.analysis.waveformReference.map {
            try Data(contentsOf: store.waveformDirectory.appendingPathComponent($0))
        }
        return .init(track: track, performance: performance, arrangement: arrangement, waveformData: waveform)
    }
}
