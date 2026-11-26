import Foundation
import Testing

@testable import TDJCore

private func sharedTrack(_ number: Int, savedDeep: Bool = false) throws -> Track {
    let source = MusicLibrarySource(platform: .iosMusic, persistentID: String(number))
    var analysis = AudioAnalysis(
        implementation: "fixture", configurationID: "fixture",
        contentSHA256: String(repeating: String(number), count: 64), sampleRate: 44100,
        frameCount: 441000, channelCount: 2, waveformFramesPerBin: 441, waveform: [],
        bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1,
        key: .init(tonic: 0, mode: .major), keyConfidence: 1, chroma: [], timbre: [])
    if savedDeep { analysis.deepBeatAnalysis = sharedDeep(analysis) }
    var track = try Track(title: "Song", mediaFilename: "\(number).caf", analysis: analysis)
    track.musicLibrarySources = [source]
    return track
}

private func sharedDeep(_ analysis: AudioAnalysis) -> DeepBeatAnalysis {
    .init(audio: .init(analysis), profile: .current, coveredFrames: analysis.frameCount,
        windowCount: 1, candidate: nil)
}

@Test func sharedCatalogueTargetsOnlyDownloadedPlaylistSongsWithMissingDeepAnalysis() throws {
    let tracks = try (1...6).map { try sharedTrack($0, savedDeep: $0 == 5) }
    let items = tracks.enumerated().map { index, track in
        MusicLibraryItem(source: track.musicLibrarySources![0], title: track.title, artist: "",
            assetURL: URL(fileURLWithPath: "/fixture.caf"), availability: index == 2 ? .notDownloaded : .available)
    }
    let catalog = MusicLibraryCatalog(items: items,
        playlists: [.init(id: "set", name: "Set", itemIDs: [0, 1, 2, 4, 5, 0].map { items[$0].id })])
    let targets = SharedAnalysisCatalogue.targets(
        tracks: tracks, catalog: catalog, excluding: [tracks[5].id],
        checked: [SharedAnalysisCatalogue.recordName(for: tracks[1].analysis)])
    #expect(targets.values.flatMap { $0 }.map(\.id) == [tracks[0].id])
}

@Test func sharedCatalogueValidatesExactAudioAndBoundsIncomingData() throws {
    let track = try sharedTrack(1)
    let candidate = sharedDeep(track.analysis)
    let data = try JSONEncoder().encode(candidate)
    #expect(SharedAnalysisCatalogue.decode(data, matching: track) == candidate)
    #expect(SharedAnalysisCatalogue.decode(data, matching: try sharedTrack(2)) == nil)
    #expect(SharedAnalysisCatalogue.decode(Data(repeating: 0, count: 65537), matching: track) == nil)
    #expect(SharedAnalysisCatalogue.recordName(for: track.analysis)
        == "deep-v1-" + AnalysisAudioIdentity(track.analysis).key)
}

@Test func sharedCatalogueOnlyAddsMissingEvidenceAndRetainsManualPreparation() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var target = try sharedTrack(1)
    target.preparation.gridWasEditedByUser = true
    target.preparation.correctedKey = .init(tonic: 4, mode: .minor)
    let existing = try sharedTrack(2, savedDeep: true)
    let protected = try sharedTrack(3)
    let differentAudio = try sharedTrack(4)
    var baseline = LibrarySnapshot()
    baseline.tracks = [target, existing, protected, differentAudio]
    try store.save(baseline)
    let service = try LibraryService(store: store)
    var newer = sharedDeep(existing.analysis)
    newer.completedAt = Date(timeIntervalSinceReferenceDate: 2000)

    let saved = try await service.adoptDeepAnalyses([
        target.id: sharedDeep(target.analysis),
        existing.id: newer,
        protected.id: sharedDeep(protected.analysis),
        differentAudio.id: sharedDeep(target.analysis),
    ], protectedTracks: [protected.id], onlyMissing: true)

    #expect(saved.revision == baseline.revision + 1)
    #expect(saved.track(id: target.id)?.analysis.deepBeatAnalysis == sharedDeep(target.analysis))
    #expect(saved.track(id: target.id)?.preparation == target.preparation)
    #expect(saved.track(id: existing.id) == existing)
    #expect(saved.track(id: protected.id) == protected)
    #expect(saved.track(id: differentAudio.id) == differentAudio)
    #expect(try store.load().revision == saved.revision)
}
