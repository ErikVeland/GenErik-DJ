import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@Test @MainActor func automaticSharingDefersLoadedTracksAndPreservesLocalCues() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let analysis = AudioAnalysis(
        implementation: "fixture", configurationID: "fixture",
        contentSHA256: String(repeating: "a", count: 64), sampleRate: 44100, frameCount: 441000,
        channelCount: 2, waveformFramesPerBin: 441, waveform: [], bpm: 120, beatAnchorFrame: 0,
        tempoConfidence: 1, key: .init(tonic: 0, mode: .major), keyConfidence: 1, chroma: [], timbre: [])
    var track = try Track(title: "Shared", mediaFilename: "shared.wav", analysis: analysis)
    track.preparation.gridWasEditedByUser = true
    track.preparation.correctedKey = .init(tonic: 4, mode: .minor)
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)
    var performance = PerformancePreparation()
    performance.cues[track.id] = [2: .init(frame: 1000)]
    performance.traktorCueHistory = [track.id: .init(protectedEmptySlots: [0, 1])]
    try performance.save(to: root.appendingPathComponent("performance.json"))
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    var remote = track
    remote.analysis.deepBeatAnalysis = .init(
        audio: .init(analysis), profile: .current,
        coveredFrames: analysis.frameCount, windowCount: 1, candidate: nil)
    let vault = try CloudPreparationVault(root: root.appendingPathComponent("account"))
    let revision = try vault.retain(.analysisOnly(track: remote, arrangement: nil))
    let transfer = CloudPreparationSync.Result(root: vault.root, revisions: [revision], message: "Downloaded")
    model.loaded[.a] = track.id
    try await model.adoptAutomaticCloudResults(transfer)
    #expect(model.library.track(id: track.id)?.analysis.deepBeatAnalysis == nil)
    #expect(!model.automaticCloudRead.contains(revision.id))
    model.loaded.removeAll()
    model.nativeMusic.activeTrackID = track.id
    try await model.adoptAutomaticCloudResults(transfer)
    #expect(model.library.track(id: track.id)?.analysis.deepBeatAnalysis == nil)
    model.nativeMusic.activeTrackID = nil
    try await model.adoptAutomaticCloudResults(transfer)
    #expect(model.library.track(id: track.id)?.analysis.deepBeatAnalysis == remote.analysis.deepBeatAnalysis)
    #expect(model.library.track(id: track.id)?.preparation == track.preparation)
    #expect(model.performance.cues == performance.cues)
    #expect(model.performance.traktorCueHistory == performance.traktorCueHistory)
    let savedRevision = model.library.revision
    try await model.adoptAutomaticCloudResults(transfer)
    #expect(model.library.revision == savedRevision)
    #expect(try store.load().tracks[0].analysis.deepBeatAnalysis != nil)
    #expect(try CloudPreparationVault(root: root.appendingPathComponent("RecoveryVersions")).list().count == 1)
    await model.finishForShutdown()
}

@Test @MainActor func automaticSharingAdoptsSectionsAfterBeatUpgradeAndKeepsCorrections() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let analysis = AudioAnalysis(
        implementation: "fixture", configurationID: "fixture",
        contentSHA256: String(repeating: "a", count: 64), sampleRate: 44100, frameCount: 441000,
        channelCount: 2, waveformFramesPerBin: 441, waveform: [], bpm: 120, beatAnchorFrame: 0,
        tempoConfidence: 1, key: .init(tonic: 0, mode: .major), keyConfidence: 1, chroma: [], timbre: [])
    let track = try Track(title: "Shared", mediaFilename: "shared.wav", analysis: analysis)
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let previous = ArrangementCache(
        version: MusicalStructureAnalyzer.version - 1,
        content: analysis.contentSHA256, configuration: analysis.configurationID,
        context: .init(title: track.title, genre: track.genre),
        arrangement: .init(
            sections: [.init(start: 0, end: 441000, name: "User intro", locked: true)],
            landmarks: [], musicalEnd: 441000, rhythmicEnd: nil))
    try previous.write(to: model.arrangementURL(track.id))
    let deep = DeepBeatAnalysis(
        audio: .init(analysis), profile: .current,
        coveredFrames: analysis.frameCount, windowCount: 1,
        candidate: .init(.init(bpm: 120, firstBar: 0, beatAgreement: 0.99, barAgreement: 0.99, residualMilliseconds: 5))
    )
    let remote = try track.adoptingDeepAnalysis(deep)
    let incoming = ArrangementCache(
        version: MusicalStructureAnalyzer.version,
        content: analysis.contentSHA256, configuration: analysis.configurationID,
        context: previous.context,
        arrangement: .init(
            sections: [.init(start: 0, end: 441000, name: "Detected section")],
            landmarks: [], musicalEnd: 441000, rhythmicEnd: nil),
        automaticCues: [:], rhythmProfile: deep.profile.id)
    let vault = try CloudPreparationVault(root: root.appendingPathComponent("account"))
    let revision = try vault.retain(.analysisOnly(track: remote, arrangement: JSONEncoder().encode(incoming)))
    try await model.adoptAutomaticCloudResults(.init(root: vault.root, revisions: [revision], message: "Downloaded"))
    let saved = try JSONDecoder().decode(ArrangementCache.self, from: Data(contentsOf: model.arrangementURL(track.id)))
    #expect(saved.rhythmProfile == deep.profile.id)
    #expect(saved.version == MusicalStructureAnalyzer.version)
    #expect(saved.arrangement.sections[0].name == "User intro")
    #expect(saved.arrangement.sections[0].locked)
    #expect(model.library.track(id: track.id)?.analysis.acceptedDeepBeatAnalysis == deep)
    #expect(model.performance.cues[track.id] == nil)
    await model.finishForShutdown()
}
