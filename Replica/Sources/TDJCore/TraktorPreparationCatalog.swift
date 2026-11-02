import Foundation

public struct TraktorPreparationRecord: Codable, Equatable, Sendable {
    public let entryIndex: Int
    public let rawEntry: TraktorNMLElement
    public let persistentID: UInt64?
    public let durationSeconds: Double?
    public let bpm: Double?
    public let key: MusicalKey?
    public let gridMilliseconds: Double?
    public let warnings: [String]
    public var title: String { rawEntry.attributes["TITLE"] ?? "" }
    public var artist: String { rawEntry.attributes["ARTIST"] ?? "" }
    public var canReuseMusicalPreparation: Bool {
        bpm != nil && key != nil && gridMilliseconds != nil && durationSeconds != nil
    }

    init(entry: TraktorNMLElement, index: Int) {
        entryIndex = index
        rawEntry = entry
        func unambiguousChild(_ name: String) -> TraktorNMLElement? {
            let children = entry.children.filter { $0.name == name }
            guard let first = children.first,
                  children.dropFirst().allSatisfy({ $0 == first }) else { return nil }
            return first
        }
        let identity = unambiguousChild("ITUNES")
        let rawID = identity?.attributes["PERSISTENT_ID"] ?? ""
        persistentID = rawID.count == 16 ? UInt64(rawID, radix: 16) : nil
        let milliseconds = identity?.attributes["PLAYTIME"].flatMap(Double.init)
        durationSeconds = milliseconds.flatMap { $0.isFinite && $0 > 0 ? $0 / 1000 : nil }
        let tempo = unambiguousChild("TEMPO")?.attributes["BPM"].flatMap(Double.init)
        bpm = tempo.flatMap { $0.isFinite && $0 > 0 && $0 <= 1000 ? $0 : nil }
        let numericKey = unambiguousChild("MUSICAL_KEY")?.attributes["VALUE"].flatMap(Int.init)
        if let numericKey, (0..<24).contains(numericKey) {
            key = .init(tonic: numericKey % 12, mode: numericKey < 12 ? .major : .minor)
        } else { key = nil }
        let grids = entry.children.filter { $0.name == "CUE_V2" && $0.attributes["TYPE"] == "4" }
        let origins = grids.compactMap { $0.attributes["START"].flatMap(Double.init) }.filter { $0.isFinite && $0 >= 0 }
        if origins.count == grids.count, let first = origins.first,
           origins.allSatisfy({ abs($0 - first) <= 0.000001 }) {
            gridMilliseconds = first
        } else { gridMilliseconds = nil }
        var warnings: [String] = []
        for name in ["ITUNES", "TEMPO", "MUSICAL_KEY"] where
            entry.children.contains(where: { $0.name == name }) && unambiguousChild(name) == nil {
            warnings.append("Conflicting \(name) elements were retained without selecting a value.")
        }
        if persistentID == nil { warnings.append("No supported iTunes persistent identity.") }
        if durationSeconds == nil { warnings.append("Source duration is unavailable.") }
        if numericKey != nil && key == nil { warnings.append("The original key code is unknown or unsupported.") }
        if grids.count > 1 && gridMilliseconds == nil { warnings.append("Multiple distinct grid origins are retained without selecting one.") }
        if origins.count != grids.count { warnings.append("An original grid position is unsupported.") }
        self.warnings = warnings
    }

    public func normalized(collectionSHA256: String, analysis: AudioAnalysis) throws -> NormalizedTraktorPreparation {
        let duration = analysis.duration
        guard duration.isFinite, duration > 0 else { throw CoreError.invalidAudio("The decoded source has no valid duration.") }
        guard let expected = durationSeconds else {
            throw CoreError.invalidAudio("The original collection item has no duration for identity verification.")
        }
        do {
            guard abs(expected - duration) <= max(0.25, min(2, expected * 0.001)) else {
                throw CoreError.invalidAudio("The audio duration differs from the original collection item. Preparation was not applied.")
            }
        }
        let grid: BeatGrid?
        if let bpm, let gridMilliseconds {
            let frame = gridMilliseconds * analysis.sampleRate / 1000
            guard frame.isFinite, frame >= 0, frame < Double(analysis.frameCount) else {
                throw CoreError.invalidAudio("The original grid lies outside this audio file.")
            }
            grid = try BeatGrid(bpm: bpm, anchorFrame: frame, sampleRate: analysis.sampleRate, downbeatOffset: 0)
        } else { grid = nil }
        var cues: [Int: PerformanceCue] = [:]
        for cue in rawEntry.children where cue.name == "CUE_V2" {
            guard let slotText = cue.attributes["HOTCUE"], let slot = Int(slotText), (0..<8).contains(slot),
                  let type = cue.attributes["TYPE"].flatMap(Int.init), [0, 4, 5].contains(type),
                  let milliseconds = cue.attributes["START"].flatMap(Double.init), milliseconds.isFinite else { continue }
            let frame = milliseconds * analysis.sampleRate / 1000
            guard frame.isFinite, frame >= 0, frame < Double(analysis.frameCount), cues[slot] == nil else {
                throw CoreError.invalidAudio("An original cue is duplicated or outside this audio file.")
            }
            let end: Double?
            if type == 5 {
                guard let length = cue.attributes["LEN"].flatMap(Double.init), length.isFinite, length > 0 else {
                    throw CoreError.invalidAudio("An original loop has no supported length.")
                }
                let value = frame + length * analysis.sampleRate / 1000
                guard value.isFinite, value > frame, value <= Double(analysis.frameCount) else {
                    throw CoreError.invalidAudio("An original loop extends beyond this audio file.")
                }
                end = value
            } else { end = nil }
            cues[slot] = .init(frame: frame, loopEnd: end, kind: type == 4 ? .grid : type == 5 ? .loop : .cue)
        }
        return .init(collectionSHA256: collectionSHA256, entryIndex: entryIndex, contentSHA256: analysis.contentSHA256,
            sampleRate: analysis.sampleRate, frameCount: analysis.frameCount, grid: grid, key: key, cues: cues)
    }
}

public struct ImportedTraktorPreparation: Codable, Equatable, Sendable {
    public let collection: TraktorCollectionReferenceSummary
    public let record: TraktorPreparationRecord
    public let matchedSource: MusicLibrarySource
    public let normalized: NormalizedTraktorPreparation
    public let mappingProfile: String
}

public struct TraktorPreparationCatalog: Sendable {
    public let summary: TraktorCollectionReferenceSummary
    public let records: [TraktorPreparationRecord]
    private let identities: [UInt64: [Int]]

    public static func read(_ data: Data, checkCancellation: @escaping @Sendable () throws -> Void = {}) throws -> Self {
        var records: [TraktorPreparationRecord] = []
        let summary = try TraktorNMLReferenceReader.scanCollection(data, checkCancellation: checkCancellation) { entry in
            records.append(.init(entry: entry, index: records.count))
        }
        guard summary.document.version == "17", summary.document.program == "Traktor DJ" else {
            throw CoreError.invalidAudio("Use an original NML version 17 DJ collection. The collection was not imported.")
        }
        var identities: [UInt64: [Int]] = [:]
        for record in records {
            try checkCancellation()
            if let id = record.persistentID { identities[id, default: []].append(record.entryIndex) }
        }
        return .init(summary: summary, records: records, identities: identities)
    }

    public func match(_ source: MusicLibrarySource) -> TraktorPreparationRecord? {
        guard let id = UInt64(source.persistentID), let positions = identities[id], positions.count == 1 else { return nil }
        return records[positions[0]]
    }

    public func bind(_ record: TraktorPreparationRecord, source: MusicLibrarySource, analysis: AudioAnalysis) throws -> ImportedTraktorPreparation {
        guard match(source)?.entryIndex == record.entryIndex else {
            throw CoreError.invalidAudio("Preparation needs a unique exact music-library identity.")
        }
        let normalized = try record.normalized(collectionSHA256: summary.sourceSHA256, analysis: analysis)
        return .init(collection: summary, record: record, matchedSource: source, normalized: normalized,
            mappingProfile: "tdj-nml17-ms-zero-based-key-v1-single-grid")
    }
}
