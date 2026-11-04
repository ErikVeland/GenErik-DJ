import Foundation
import Testing

@testable import TDJCore

private let conflictIdentity = "<ITUNES PERSISTENT_ID=\"0000000000001234\" PLAYTIME=\"1000\"/>"
private let conflictTempo = "<TEMPO BPM=\"120\"/>"
private let conflictKey = "<MUSICAL_KEY VALUE=\"0\"/>"
private func conflictCollection(_ extra: String) -> Data {
    Data(
        "<NML VERSION=\"17\"><HEAD PROGRAM=\"Traktor DJ\"/><COLLECTION ENTRIES=\"1\"><ENTRY>\(conflictIdentity)\(conflictTempo)\(conflictKey)<CUE_V2 TYPE=\"4\" START=\"0\" HOTCUE=\"-1\"/>\(extra)</ENTRY></COLLECTION></NML>"
            .utf8)
}
private func conflictAnalysis() -> AudioAnalysis {
    .init(
        implementation: "Synthetic conflict", configurationID: "synthetic",
        contentSHA256: String(repeating: "a", count: 64), sampleRate: 48000, frameCount: 48000, channelCount: 2,
        waveformFramesPerBin: 512, waveform: [], bpm: 110, beatAnchorFrame: 0, tempoConfidence: 0, key: nil,
        keyConfidence: 0, chroma: [], timbre: [])
}

@Test(arguments: ["ITUNES", "TEMPO", "MUSICAL_KEY"]) func preparationConflictWithholdsTheAmbiguousValue(_ field: String)
    throws
{
    let extra: String
    switch field {
    case "ITUNES": extra = "<ITUNES PERSISTENT_ID=\"0000000000005678\" PLAYTIME=\"2000\"/>"
    case "TEMPO": extra = "<TEMPO BPM=\"133\"/>"
    default: extra = "<MUSICAL_KEY VALUE=\"9\"/>"
    }
    let catalog = try TraktorPreparationCatalog.read(conflictCollection(extra))
    let record = try #require(catalog.records.first)
    #expect(!record.canReuseMusicalPreparation)
    #expect(record.rawEntry.children.filter { $0.name == field }.count == 2)
    #expect(record.warnings.contains { $0.contains("Conflicting \(field)") })
    let source = MusicLibrarySource(platform: .iosMusic, persistentID: "4660")
    if field == "ITUNES" {
        #expect(record.persistentID == nil && record.durationSeconds == nil)
        #expect(catalog.match(source) == nil)
        #expect(throws: (any Error).self) { try catalog.bind(record, source: source, analysis: conflictAnalysis()) }
    } else {
        let bound = try catalog.bind(record, source: source, analysis: conflictAnalysis())
        if field == "TEMPO" {
            #expect(record.bpm == nil && bound.normalized.grid == nil)
            #expect(bound.normalized.key != nil)
        } else {
            #expect(record.key == nil && bound.normalized.key == nil)
            #expect(bound.normalized.grid?.bpm == 120)
        }
    }
}

@Test func preparationIdenticalRepeatedCriticalElementsRemainUsable() throws {
    let catalog = try TraktorPreparationCatalog.read(conflictCollection(conflictIdentity + conflictTempo + conflictKey))
    let record = try #require(catalog.records.first)
    #expect(record.canReuseMusicalPreparation)
    #expect(record.persistentID == 4660 && record.bpm == 120)
    #expect(record.warnings.isEmpty)
    let bound = try catalog.bind(
        record, source: .init(platform: .iosMusic, persistentID: "4660"), analysis: conflictAnalysis())
    #expect(bound.normalized.grid?.bpm == 120)
    #expect(bound.normalized.key == .init(tonic: 0, mode: .major))
}
