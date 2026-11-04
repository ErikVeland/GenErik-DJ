import AVFoundation
import Foundation
import Testing

@testable import TDJCore

@Test func coldStreamedPlaybackDoesNotBuildAWholePCMCache() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let source = store.mediaDirectory.appendingPathComponent("cold.caf")
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000))
    buffer.frameLength = 48000
    for c in 0..<2 { buffer.floatChannelData![c].initialize(repeating: 0.1, count: 48000) }
    var file: AVAudioFile? = try AVAudioFile(forWriting: source, settings: format.settings)
    for _ in 0..<8 { try file!.write(from: buffer) }
    file = nil
    let analysis = try AudioAnalyzer.waveformOnly(url: source)
    let track = try Track(title: "Cold", mediaFilename: "cold.caf", analysis: analysis)
    let asset = try await PCMCache.prepareAsync(track: track, store: store, streamed: true)
    #expect(asset.isStreamed)
    let pcm = store.root.appendingPathComponent("PlaybackCache/\(track.id)-stereo-f32-v1.pcm")
    #expect(!FileManager.default.fileExists(atPath: pcm.path))
}

private func openingFixture() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
}

@Test func nativeOpeningHasRealPartialWaveformAndKeepsPreparationThroughAnalysis() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let url = openingFixture()
    let opening = try await NativePlaybackOpening.open(url: url, sourceIdentity: "first-use")
    #expect(opening.analysis.waveformDecodedFrames == 22050)
    #expect(opening.analysis.waveform.count == 50)
    #expect(opening.analysis.waveform.contains { $0.maximum > 0 || $0.minimum < 0 })
    let item = MusicLibraryItem(
        source: .init(platform: .iosMusic, persistentID: "first-use"), title: "First use", artist: "Fixture",
        assetURL: url, availability: .available)
    let snapshot = try await service.registerNativePlayback(analysis: opening.analysis, metadata: .init(item: item))
    let initial = try #require(snapshot.tracks.first)
    #expect(initial.nativePlaybackIdentity != nil)
    #expect(try store.hydrate(initial).analysis.waveform.count == 50)
    var manual = initial.preparation
    manual.grid = try BeatGrid(bpm: 123, anchorFrame: 441, sampleRate: initial.analysis.sampleRate)
    manual.gridIsManual = true
    manual.correctedKey = MusicalKey(tonic: 1, mode: .minor)
    _ = try await service.updatePreparation(trackID: initial.id, preparation: manual)
    let analysed = try await service.analyzeNativeMusic(url: url, musicLibrary: .init(item: item))
    let final = try #require(analysed.tracks.first)
    #expect(analysed.tracks.count == 1)
    #expect(final.id == initial.id)
    #expect(final.analysis.contentSHA256 == (try AudioAnalyzer.sha256(url: url)))
    #expect(final.id != final.analysis.contentSHA256)
    #expect(final.preparation == manual)
    #expect(final.analysis.musicalAnalysisDeferred != true)
    #expect(try store.load().tracks.first?.id == initial.id)
    let imported = try await service.importAudio(url: url)
    #expect(imported.tracks.count == 1)
    #expect(imported.tracks.first?.id == initial.id)
    #expect(imported.tracks.first?.nativeLibraryOnly != true)
    #expect(imported.tracks.first?.preparation == manual)
}

@Test func nativeWaveformCompletesWithoutChangingTheOpeningAndWritesExactPCM() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let opening = try await NativePlaybackOpening.open(url: openingFixture(), sourceIdentity: "waveform")
    let cache = root.appendingPathComponent("audio.pcm")
    let result = try await opening.waveform(cache: cache, matching: opening.analysis) { _ in }
    #expect(opening.analysis.waveform.count == 50)
    #expect(result.waveformDecodedFrames == nil)
    #expect(
        result.waveform.count
            == Int((result.frameCount + Int64(result.waveformFramesPerBin) - 1) / Int64(result.waveformFramesPerBin)))
    #expect(result.waveform.contains { $0.maximum > 0.1 })
    #expect((try cache.resourceValues(forKeys: [.fileSizeKey]).fileSize) == Int(result.frameCount) * 8)
    let file = try AVAudioFile(forReading: openingFixture(), commonFormat: .pcmFormatFloat32, interleaved: false)
    let buffer = try #require(
        AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
    try file.read(into: buffer)
    let data = try Data(contentsOf: cache)
    data.withUnsafeBytes { bytes in
        let samples = bytes.bindMemory(to: Float.self)
        for n in stride(from: 0, to: Int(file.length), by: 137) {
            #expect(samples[2 * n] == buffer.floatChannelData![0][n])
            #expect(samples[2 * n + 1] == buffer.floatChannelData![file.processingFormat.channelCount == 1 ? 0 : 1][n])
        }
    }
}

@Test func existingNativeTrackKeepsIdentityPreparationAndBarVersionAcrossMetadataLengthChanges() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let url = openingFixture()
    let opening = try await NativePlaybackOpening.open(url: url, sourceIdentity: "known-creep")
    let analysed = try AudioAnalyzer.analyze(url: url)
    var savedAnalysis = analysed.replacingWaveform(
        [], configurationID: analysed.configurationID, frameCount: 22_746_240, decodedFrames: nil)
    savedAnalysis.barAnalysisVersion = BarStartAnalysis.version
    let item = MusicLibraryItem(
        source: .init(platform: .iosMusic, persistentID: "4660"), title: "Creep", artist: "TLC", assetURL: url,
        availability: .available)
    var track = try Track(title: "Creep", mediaFilename: "native.caf", analysis: savedAnalysis)
    track.nativeLibraryOnly = true
    track.musicLibrarySources = [item.source]
    track.preparation.gridWasEditedByUser = true
    track.preparation.gridLocked = true
    let xml = """
        <NML VERSION="17"><HEAD PROGRAM="Traktor DJ"/><COLLECTION ENTRIES="1">
        <ENTRY TITLE="Creep" LOCK="0"><ITUNES PERSISTENT_ID="0000000000001234" PLAYTIME="515787.7551020408"/>
        <MUSICAL_KEY VALUE="21"/><TEMPO BPM="136.02"/>
        <CUE_V2 NAME="Grid" HOTCUE="-1" START="180.574" TYPE="4"/>
        <CUE_V2 NAME="Entry" HOTCUE="2" START="2000" TYPE="0"/>
        </ENTRY></COLLECTION></NML>
        """
    let catalog = try TraktorPreparationCatalog.read(Data(xml.utf8))
    track.traktorPreparation = try catalog.bind(
        #require(catalog.records.first), source: item.source, analysis: savedAnalysis)
    let imported = track.traktorPreparation
    let manual = track.preparation
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)
    let service = try LibraryService(store: store)
    let result = try await service.registerNativePlayback(analysis: opening.analysis, metadata: .init(item: item))
    let current = try #require(result.tracks.first)
    #expect(result.tracks.count == 1)
    #expect(current.id == track.id)
    #expect(current.analysis.frameCount == 22_746_240)
    #expect(current.preparation == manual)
    #expect(current.traktorPreparation == imported)
    #expect(current.traktorPreparation?.normalized.cues[2]?.frame == 88200)
    #expect(current.musicLibrarySources == [item.source])
    #expect(current.analysis.barAnalysisVersion == BarStartAnalysis.version)
    #expect(current.nativeSourceNeedsAnalysis == true)
    let replaced = current.analysis.replacingWaveform(opening.analysis.waveform)
    #expect(replaced.barAnalysisVersion == BarStartAnalysis.version)
    #expect(try store.load(includeWaveforms: false).tracks.first?.id == track.id)
}

@Test func assetReaderBackendMatchesFileSamplesAcrossBlockBoundariesAndSeeks() async throws {
    let url = openingFixture()
    let source = try await DecodedAudioSource.asset(url: url)
    let reference = try DecodedAudioSource.file(url: url)
    #expect(source.frames == reference.frames)
    for first: Int64 in [0, 8192, 16447, 44100, 22050, source.frames - 8192] {
        var actual = [Float](repeating: 0, count: 8192 * 2)
        var expected = actual
        try actual.withUnsafeMutableBufferPointer { try source.read(first: first, count: 8192, into: $0.baseAddress!) }
        try expected.withUnsafeMutableBufferPointer {
            try reference.read(first: first, count: 8192, into: $0.baseAddress!)
        }
        #expect(actual == expected)
    }
}

@Test func twoNativeAliasesKeepTheirOwnIdentitiesAfterContentAnalysis() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let service = try LibraryService(store: WorkspaceStore(root: root))
    var identities = [String]()
    for id in ["alias-a", "alias-b"] {
        let opening = try await NativePlaybackOpening.open(url: openingFixture(), sourceIdentity: id)
        let item = MusicLibraryItem(
            source: .init(platform: .iosMusic, persistentID: id), title: id, artist: "Fixture",
            assetURL: openingFixture(), availability: .available)
        let registered = try await service.registerNativePlayback(
            analysis: opening.analysis, metadata: .init(item: item))
        let identity = try #require(
            registered.tracks.first { $0.musicLibrarySources?.contains(item.source) == true }?.id)
        identities.append(identity)
        _ = try await service.analyzeNativeMusic(url: openingFixture(), musicLibrary: .init(item: item))
    }
    let snapshot = await service.snapshot()
    #expect(identities[0] != identities[1])
    #expect(snapshot.tracks.count == 2)
    for (n, id) in ["alias-a", "alias-b"].enumerated() {
        #expect(
            snapshot.track(id: identities[n])?.musicLibrarySources == [.init(platform: .iosMusic, persistentID: id)])
    }
}

@Test func cancelledNativeWaveformDoesNotPublishPartialPCM() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let opening = try await NativePlaybackOpening.open(url: openingFixture(), sourceIdentity: "cancel")
    let cache = root.appendingPathComponent("cancel.pcm")
    let task = Task { try await opening.waveform(cache: cache, matching: opening.analysis) { _ in } }
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("Cancelled waveform completed")
    } catch is CancellationError {}
    #expect(!FileManager.default.fileExists(atPath: cache.path))
    #expect(
        (try? FileManager.default.contentsOfDirectory(atPath: root.path))?.contains { $0.hasSuffix(".partial") } != true
    )
}
