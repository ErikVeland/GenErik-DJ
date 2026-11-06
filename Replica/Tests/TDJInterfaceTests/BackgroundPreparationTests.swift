import AVFoundation
import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@MainActor private final class ClockMusicLibrary: LocalMusicLibraryProviding {
    let snapshot: MusicLibraryCatalog
    var preparations = 0
    var directPlayback = false
    var beforePreparation: ((MusicLibraryItem) async throws -> Void)?
    init(_ items: [MusicLibraryItem]) { snapshot = .init(items: items, playlists: []) }
    func catalog() async throws -> MusicLibraryCatalog { snapshot }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        preparations += 1
        try await beforePreparation?(item)
        return .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
    func playbackSource(_ item: MusicLibraryItem) async throws -> PreparedMusicLibraryAudio? {
        guard directPlayback else { return nil }
        return .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
}

@Test @MainActor func expiringBackgroundAnalysisDoesNotRestartUntilForeground() async throws {
    let item = clockItem("expiry", duration: 16)
    let provider = ClockMusicLibrary([item])
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: workspace) }
    let model = try ReplicaModel(
        root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    let (started, signal) = AsyncStream<Void>.makeStream()
    provider.beforePreparation = { _ in
        signal.yield(())
        try await Task.sleep(for: .seconds(30))
    }

    model.setLibraryAnalysisBackgrounded(true)
    let granted = model.beginBackgroundLibraryAnalysis { _, _ in }
    let id = try #require(granted)
    let work = Task {
        defer { signal.finish() }
        return await model.runBackgroundLibraryAnalysis(id)
    }
    for await _ in started { break }
    model.endBackgroundLibraryAnalysis(id)
    #expect(await work.value == false)
    await model.flushNativeMusicAnalysis()
    #expect(provider.preparations == 1)
    #expect(model.preparedTrack(for: item) == nil)

    provider.beforePreparation = nil
    model.setLibraryAnalysisBackgrounded(false)
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    #expect(provider.preparations == 3)
    #expect(model.preparedTrack(for: item) != nil)
    await model.finishForShutdown()
}

private func clockFixture() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
}
private func clockItem(_ id: String, duration: Double) -> MusicLibraryItem {
    .init(
        source: .init(platform: .iosMusic, persistentID: id), title: "Clock \(id)", artist: "Fixture",
        duration: duration, assetURL: clockFixture(), availability: .available)
}

@Test @MainActor func libraryChecksShortTracksFirstAndSavesMatchingBeforeStructure() async throws {
    let short = clockItem("short", duration: 16)
    let unknown = clockItem("unknown", duration: 0)
    let provider = ClockMusicLibrary([unknown, short])
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: workspace) }
    let model = try ReplicaModel(
        root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    var reads: [String] = []
    provider.beforePreparation = { item in
        reads.append(item.id)
        if reads.count == 2 {
            #expect(item.id == unknown.id)
            #expect(model.analysisProgress?.done == 1)
            #expect(model.analysisProgress?.total == 4)
            let track = try #require(model.preparedTrack(for: short))
            #expect(abs((track.bpm ?? 0) - 120) < 0.5)
            #expect(!FileManager.default.fileExists(atPath: model.arrangementURL(track.id).path))
        }
        if reads.count == 3 {
            #expect(model.analysisProgress?.done == 2)
            #expect(model.preparedTrack(for: unknown) != nil)
        }
    }

    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    #expect(reads == [short.id, unknown.id, short.id])
    let track = try #require(model.preparedTrack(for: short))
    let cache = try JSONDecoder().decode(ArrangementCache.self, from: Data(contentsOf: model.arrangementURL(track.id)))
    #expect(cache.automaticCues != nil)
    if let progress = model.analysisProgress { #expect(progress.done == 4) }
    provider.beforePreparation = nil
    await model.finishForShutdown()
}
@MainActor private func preparationModel(_ items: [MusicLibraryItem], sources: [URL] = []) throws -> (ReplicaModel, URL)
{
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(
        root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: ClockMusicLibrary(items),
        automaticTraktorSources: sources)
    return (model, workspace)
}

@Test @MainActor func analyserStartsWhenTheLibraryOpensAndGivesBPMs() async throws {
    let item = clockItem("4660", duration: NativeAnalysisPlan.mixThresholdSeconds + 1)
    let (model, workspace) = try preparationModel([item])
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    let track = try #require(model.preparedTrack(for: item))
    #expect(abs((track.bpm ?? 0) - 120) < 0.5)
    let cacheURL = model.arrangementURL(track.id)
    let saved = try Data(contentsOf: cacheURL)
    let cache = try JSONDecoder().decode(ArrangementCache.self, from: saved)
    #expect(cache.version == MusicalStructureAnalyzer.version)
    let cues = try #require(cache.automaticCues)
    if track.automaticBarGrid == nil || track.key == nil || track.keyDecision.needsReview || cues.isEmpty {
        #expect(model.analysisProgress?.message?.contains("need review") == true)
    } else {
        #expect(model.analysisProgress == nil)
    }
    let log = try String(contentsOf: workspace.appendingPathComponent("analysis.log"), encoding: .utf8)
    #expect(log.contains("Analysis queue: 1 songs"))
    await model.finishForShutdown()

    let provider = ClockMusicLibrary([item])
    provider.directPlayback = true
    let reopened = try ReplicaModel(
        root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await reopened.openNativeMusicLibrary()
    await reopened.flushNativeMusicAnalysis()
    #expect(provider.preparations == 0)
    reopened.performance.cues[track.id] = [0: .init(frame: 42)]
    reopened.loadNativeMusic(item, deck: .a)
    await reopened.flushWrites()
    await reopened.flushDeckAnalysis()
    await reopened.prepareArrangement(deck: .a)
    #expect(reopened.track(.a)?.nativeSourceNeedsAnalysis != true)
    #expect(reopened.arrangements[track.id] == cache.arrangement)
    #expect(reopened.performance.cues[track.id]?[0]?.frame == 42)
    #expect(try Data(contentsOf: cacheURL) == saved)
    #expect(provider.preparations == 0)
    await reopened.finishForShutdown()
}

@Test @MainActor func staleTemporaryExportsAreRemovedBeforeAnalysis() async throws {
    let (model, workspace) = try preparationModel([])
    defer { try? FileManager.default.removeItem(at: workspace) }
    let stale = workspace.appendingPathComponent(".native-source-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
    try Data(count: 64).write(to: stale.appendingPathComponent("left.caf"))
    await model.removeStaleNativeSources()
    #expect(!FileManager.default.fileExists(atPath: stale.path))
}

private func collectionXML(bpm: Int, persistentHex: String) -> Data {
    Data(
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <NML VERSION="17"><HEAD PROGRAM="Traktor DJ"/><COLLECTION ENTRIES="1">
        <ENTRY UUID="e" TITLE="Clock" ARTIST="Fixture"><ITUNES PERSISTENT_ID="\(persistentHex)" PLAYTIME="16000"/>
        <MUSICAL_KEY VALUE="21"/><TEMPO BPM="\(bpm)"/><CUE_V2 HOTCUE="-1" START="0" TYPE="4"/></ENTRY></COLLECTION></NML>
        """.utf8)
}

@Test @MainActor func collectionImportsAtLaunchAndGivesEverySongItsTempoAndKey() async throws {
    let inbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nml")
    defer { try? FileManager.default.removeItem(at: inbox) }
    try collectionXML(bpm: 127, persistentHex: "0000000000001234").write(to: inbox)
    let item = MusicLibraryItem(
        source: .init(platform: .iosMusic, persistentID: String(0x1234)), title: "Clock", artist: "Fixture",
        duration: 16, assetURL: nil, availability: .notDownloaded)
    let (model, workspace) = try preparationModel([item], sources: [inbox])
    defer { try? FileManager.default.removeItem(at: workspace) }
    // The launch sequence: open the Music library and refresh preparation.
    await model.refreshMusicLibrary()
    await model.refreshTraktorPreparation()
    #expect(model.traktorPreparationRecords == 1)
    #expect(model.browserHints[item.id]?.bpm == 127)
    #expect(model.browserHints[item.id]?.key != nil)
}

@Test @MainActor func linkedCollectionIsImportedAgainWhenItChanges() async throws {
    let linked = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nml")
    defer { try? FileManager.default.removeItem(at: linked) }
    try collectionXML(bpm: 121, persistentHex: "0000000000005678").write(to: linked)
    let item = MusicLibraryItem(
        source: .init(platform: .iosMusic, persistentID: String(0x5678)), title: "Clock", artist: "Fixture",
        duration: 16, assetURL: nil, availability: .notDownloaded)
    let (model, workspace) = try preparationModel([item])
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.refreshMusicLibrary()
    await model.importTraktorPreparation(linked)
    #expect(model.browserHints[item.id]?.bpm == 121)
    try collectionXML(bpm: 125, persistentHex: "0000000000005678").write(to: linked)
    await model.refreshTraktorPreparation(force: true)
    #expect(model.browserHints[item.id]?.bpm == 125)
}

@Test(arguments: DeckID.allCases, [false, true]) @MainActor
func deckSelectionCompletesDeferredAnalysisWithoutOpeningTheLibrary(deck: DeckID, preprepared: Bool) async throws {
    let item = clockItem("deck-priority", duration: NativeAnalysisPlan.mixThresholdSeconds + 1)
    let (model, workspace) = try preparationModel([item])
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.refreshMusicLibrary()
    if preprepared {
        model.adoptLibrary(
            try await model.service.analyzeNativeMusic(
                url: clockFixture(), musicLibrary: .init(item: item), quickLoad: true))
        #expect(model.preparedTrack(for: item)?.analysis.musicalAnalysisDeferred == true)
    }
    model.loadNativeMusic(item, deck: deck)
    await model.flushWrites()
    await model.flushDeckAnalysis()
    let track = try #require(model.track(deck))
    #expect(track.analysis.musicalAnalysisDeferred != true)
    #expect(abs((track.bpm ?? 0) - 120) < 0.5)
    #expect(track.grid != nil)
    #expect(model.preparedTrack(for: item)?.analysis.musicalAnalysisDeferred != true)
    #expect(!model.preparingPlayback.contains(deck))
    await model.finishForShutdown()
}

enum SavedAnalysisSource: CaseIterable, Sendable { case managed, native, musicWithMissingCopy }

@Test(arguments: SavedAnalysisSource.allCases) @MainActor
func launchReanalysesSavedTracksAndResumesWithoutRepeatingCompletedWork(source: SavedAnalysisSource) async throws {
    let item = clockItem("refresh", duration: 16)
    let provider = ClockMusicLibrary(source == .managed ? [] : [item])
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: workspace) }
    let store = try WorkspaceStore(root: workspace)
    var legacy = AudioAnalysis(
        implementation: "Fixture",
        configurationID: "independent-dsp-0.4.0-meter-context-supported-pulse-phase-adaptive-candidate-multiband-consensus-tuned-hpcp-library-refresh-1-60.0-200.0",
        contentSHA256: try AudioAnalyzer.sha256(url: clockFixture()), sampleRate: 44100, frameCount: 705600,
        channelCount: 2, waveformFramesPerBin: 512, waveform: [], bpm: 126, beatAnchorFrame: 0,
        tempoConfidence: 1, key: .init(tonic: 0, mode: .major), keyConfidence: 1, chroma: [], timbre: [])
    legacy.barAnalysisVersion = BarStartAnalysis.version
    var track = try Track(title: item.title, artist: item.artist, mediaFilename: "clock.wav", analysis: legacy)
    let manualGrid = try BeatGrid(bpm: 126, anchorFrame: 480, sampleRate: 44100, downbeatOffset: 2)
    let manualKey = MusicalKey(tonic: 5, mode: .minor)
    track.preparation.grid = manualGrid
    track.preparation.gridIsManual = true
    track.preparation.correctedKey = manualKey
    if source == .managed {
        try FileManager.default.copyItem(at: clockFixture(), to: store.mediaDirectory.appendingPathComponent(track.mediaFilename))
    } else {
        track.musicLibrarySources = [item.source]
        if source == .native { track.nativeLibraryOnly = true }
    }
    var library = LibrarySnapshot()
    library.tracks = [track]
    _ = try store.save(library)

    let model = try ReplicaModel(root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    let locked = ArrangementSection(start: 0, end: 192000, role: .verse, name: "Locked verse", locked: true)
    let old = ArrangementCache(
        version: MusicalStructureAnalyzer.version, content: legacy.contentSHA256, configuration: legacy.configurationID,
        context: .init(title: track.title, genre: track.genre),
        arrangement: .init(sections: [locked], landmarks: [], musicalEnd: Double(legacy.frameCount), rhythmicEnd: nil),
        automaticCues: [:])
    try old.write(to: model.arrangementURL(track.id))
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    let refreshed = try #require(model.library.track(id: track.id))
    #expect(refreshed.analysis.configurationID == AnalysisConfiguration().id)
    #expect(refreshed.grid == manualGrid)
    #expect(refreshed.key == manualKey)
    let cacheURL = model.arrangementURL(track.id)
    let saved = try Data(contentsOf: cacheURL)
    let cache = try JSONDecoder().decode(ArrangementCache.self, from: saved)
    #expect(cache.configuration == AnalysisConfiguration().id)
    #expect(cache.arrangement.sections.contains(locked))
    #expect(cache.automaticCues?.values.contains { $0.sectionName == locked.label } == true)
    await model.finishForShutdown()

    let reopened = try ReplicaModel(root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    let previousReads = provider.preparations
    let previousRevision = reopened.library.revision
    await reopened.openNativeMusicLibrary()
    await reopened.flushNativeMusicAnalysis()
    #expect(provider.preparations == previousReads)
    #expect(reopened.library.revision == previousRevision)
    #expect(try Data(contentsOf: cacheURL) == saved)
    await reopened.finishForShutdown()
}

@Test @MainActor func backgroundTransitionRequiresSystemAnalysisTime() async throws {
    let item = clockItem("suspended", duration: 16)
    let (model, workspace) = try preparationModel([item])
    defer { try? FileManager.default.removeItem(at: workspace) }
    model.setLibraryAnalysisBackgrounded(true)
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    #expect(model.preparedTrack(for: item) == nil)
    #expect(model.libraryAnalysisNeedsWork)

    var checked = 0
    let granted = model.beginBackgroundLibraryAnalysis { done, _ in checked = done }
    let id = try #require(granted)
    #expect(model.beginBackgroundLibraryAnalysis { _, _ in } == nil)
    #expect(await model.runBackgroundLibraryAnalysis(id))
    #expect(checked == 2)
    #expect(model.preparedTrack(for: item) != nil)
    #expect(!model.libraryAnalysisNeedsWork)
    model.endBackgroundLibraryAnalysis(id)
    #expect(await model.runBackgroundLibraryAnalysis(id) == false)
    await model.finishForShutdown()
}
