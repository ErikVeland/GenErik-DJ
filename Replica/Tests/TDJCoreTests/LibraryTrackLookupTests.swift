import Foundation
import Testing
@testable import TDJCore

private func indexedTrack(_ number: Int, title: String) throws -> Track {
    let analysis = AudioAnalysis(implementation: "index-test", configurationID: "index-test",
        contentSHA256: String(format: "%064x", number), sampleRate: 48000, frameCount: 48000,
        channelCount: 2, waveformFramesPerBin: 512, waveform: [], bpm: 120, beatAnchorFrame: 0,
        tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    return try Track(title: title, mediaFilename: "index-test.wav", analysis: analysis)
}

private func indexedFixture() throws -> LibrarySnapshot {
    var snapshot = LibrarySnapshot()
    snapshot.revision = 9
    snapshot.tracks = [try indexedTrack(1, title: "First"), try indexedTrack(2, title: "Second")]
    return snapshot
}

@Test func preparedTrackLookupKeepsFirstDuplicateAndHandlesAbsentKey() throws {
    var raw = try indexedFixture()
    var duplicate = raw.tracks[0]
    duplicate.title = "Later duplicate"
    raw.tracks.append(duplicate)
    let prepared = raw.preparingTrackLookup()
    #expect(prepared.track(id: duplicate.id)?.title == "First")
    #expect(prepared.track(id: raw.tracks[1].id)?.title == "Second")
    #expect(prepared.track(id: "missing") == nil)
    #expect(prepared.tracks == raw.tracks)
}

@Test func preparedTrackLookupInvalidatesOnNestedEditReorderRemovalAndAppend() throws {
    let raw = try indexedFixture()
    let original = raw.preparingTrackLookup()
    var changed = original
    changed.tracks[1].title = "Edited"
    changed.tracks[1].preparation.correctedKey = .init(tonic: 4, mode: .minor)
    #expect(changed.track(id: raw.tracks[1].id)?.title == "Edited")
    #expect(changed.track(id: raw.tracks[1].id)?.preparation.correctedKey?.tonic == 4)
    changed.tracks.swapAt(0, 1)
    #expect(changed.track(id: raw.tracks[1].id)?.title == "Edited")
    changed.tracks.removeFirst()
    #expect(changed.track(id: raw.tracks[1].id) == nil)
    let third = try indexedTrack(3, title: "Third")
    changed.tracks.append(third)
    #expect(changed.track(id: third.id) == third)
    #expect(original.track(id: raw.tracks[1].id)?.title == "Second")
}

@Test func preparedTrackLookupDoesNotChangeEqualityOrEncodedLibraryFields() throws {
    let raw = try indexedFixture()
    let prepared = raw.preparingTrackLookup()
    #expect(prepared == raw)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let originalData = try encoder.encode(raw)
    let preparedData = try encoder.encode(prepared)
    #expect(preparedData == originalData)
    let decoded = try JSONDecoder().decode(LibrarySnapshot.self, from: preparedData)
    #expect(decoded == raw)
    #expect(decoded.track(id: raw.tracks[1].id) == raw.tracks[1])
}

@Test func sameRevisionPreparedSnapshotsDoNotShareAnIndexForDifferentTracks() throws {
    let first = try indexedFixture().preparingTrackLookup()
    var second = LibrarySnapshot()
    second.revision = first.revision
    second.tracks = [try indexedTrack(3, title: "Other library")]
    second = second.preparingTrackLookup()
    #expect(second.track(id: first.tracks[0].id) == nil)
    #expect(first.track(id: second.tracks[0].id) == nil)
    #expect(second.track(id: second.tracks[0].id)?.title == "Other library")
}

@Test func unpreparedPublicSnapshotPreservesLookupSemantics() throws {
    var raw = try indexedFixture()
    #expect(raw.track(id: raw.tracks[1].id) == raw.tracks[1])
    raw.tracks.reverse()
    #expect(raw.track(id: raw.tracks[0].id) == raw.tracks[0])
    #expect(raw.track(id: "missing") == nil)
}
