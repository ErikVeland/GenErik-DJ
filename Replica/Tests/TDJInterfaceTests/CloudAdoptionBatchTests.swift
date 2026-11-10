import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface

@Test @MainActor func cloudAdoptionSavesAGroupOnceAndDefersLoadedTracks() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    for index in 1...4 {
        let analysis = AudioAnalysis(
            implementation: "fixture", configurationID: "fixture",
            contentSHA256: String(repeating: String(index), count: 64), sampleRate: 44100,
            frameCount: 441000, channelCount: 2, waveformFramesPerBin: 441, waveform: [],
            bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1,
            key: .init(tonic: 0, mode: .major), keyConfidence: 1, chroma: [], timbre: [])
        var track = try Track(title: "Track \(index)", mediaFilename: "\(index).caf", analysis: analysis)
        track.preparation.gridWasEditedByUser = true
        track.preparation.correctedKey = .init(tonic: 4, mode: .minor)
        library.tracks.append(track)
    }
    try store.save(library)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    defer { model.stopAutomaticPreparationSharing() }
    model.loaded[.a] = library.tracks[3].id
    let vault = try CloudPreparationVault(root: root.appendingPathComponent("account"))
    var revisions: [CloudPreparationVault.Revision] = []
    for original in library.tracks {
        var remote = original
        remote.analysis.deepBeatAnalysis = .init(audio: .init(original.analysis), profile: .current,
            coveredFrames: original.analysis.frameCount, windowCount: 1, candidate: nil)
        remote.analysis.deepBeatAnalysis?.completedAt = Date(timeIntervalSinceReferenceDate: 2000)
        revisions.append(try vault.retain(.analysisOnly(track: remote, arrangement: nil)))
    }
    var older = library.tracks[0]
    older.analysis.deepBeatAnalysis = .init(audio: .init(older.analysis), profile: .current,
        coveredFrames: older.analysis.frameCount, windowCount: 1, candidate: nil)
    older.analysis.deepBeatAnalysis?.completedAt = Date(timeIntervalSinceReferenceDate: 1000)
    revisions.append(try vault.retain(.analysisOnly(track: older, arrangement: nil)))
    let before = model.library.revision
    try await model.adoptAutomaticCloudResults(.init(root: vault.root, revisions: revisions, message: "Downloaded"))
    #expect(model.library.revision == before + 1)
    #expect(model.library.tracks.prefix(3).allSatisfy { $0.analysis.deepBeatAnalysis != nil })
    #expect(model.library.tracks[3].analysis.deepBeatAnalysis == nil)
    #expect(model.library.tracks[0].analysis.deepBeatAnalysis?.completedAt == Date(timeIntervalSinceReferenceDate: 2000))
    #expect(!model.automaticCloudRead.contains(revisions[3].id))
    for index in 0..<4 {
        #expect(model.library.tracks[index].preparation == library.tracks[index].preparation)
    }
    #expect(try store.load().revision == before + 1)
    #expect(try CloudPreparationVault(root: root.appendingPathComponent("RecoveryVersions")).list().count == 3)
    await model.finishForShutdown()
}
