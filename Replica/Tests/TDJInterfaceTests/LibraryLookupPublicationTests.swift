import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface

private func publicationTrack(_ number: Int, title: String) throws -> Track {
    let analysis = AudioAnalysis(implementation: "publication-test", configurationID: "publication-test",
        contentSHA256: String(format: "%064x", number), sampleRate: 48000, frameCount: 48000,
        channelCount: 2, waveformFramesPerBin: 512, waveform: [], bpm: 120, beatAnchorFrame: 0,
        tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    return try Track(title: title, mediaFilename: "publication-test.wav", analysis: analysis)
}

@MainActor private func publicationModel() throws -> (ReplicaModel, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    return (try ReplicaModel(root: root, playback: PlaybackController(offline: true)), root)
}

@Test @MainActor func equalRevisionAdoptionImmediatelyReplacesTrackMetadata() async throws {
    let (model, root) = try publicationModel()
    defer { try? FileManager.default.removeItem(at: root) }
    var first = LibrarySnapshot()
    first.revision = 8
    first.tracks = [try publicationTrack(1, title: "Original")]
    model.adoptLibrary(first)
    model.loaded[.a] = first.tracks[0].id
    #expect(model.track(.a)?.title == "Original")
    var changed = first
    changed.tracks[0].title = "Same revision edit"
    model.adoptLibrary(changed)
    #expect(model.track(.a)?.title == "Same revision edit")
    #expect(first.tracks[0].title == "Original")
    await model.finishForShutdown()
}

@Test @MainActor func directPublicLibraryMutationImmediatelyInvalidatesLoadedLookup() async throws {
    let (model, root) = try publicationModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let first = try publicationTrack(1, title: "First")
    let second = try publicationTrack(2, title: "Second")
    model.library.tracks = [first, second]
    model.loaded[.a] = second.id
    #expect(model.track(.a)?.title == "Second")
    model.library.tracks.swapAt(0, 1)
    model.library.tracks[0].title = "Moved and edited"
    #expect(model.track(.a)?.title == "Moved and edited")
    model.library.tracks.removeFirst()
    #expect(model.track(.a) == nil)
    await model.finishForShutdown()
}

@Test @MainActor func staleAdoptionCannotRestoreRemovedTrackOrOldMetadata() async throws {
    let (model, root) = try publicationModel()
    defer { try? FileManager.default.removeItem(at: root) }
    var older = LibrarySnapshot()
    older.revision = 7
    older.tracks = [try publicationTrack(1, title: "Old")]
    var newer = older
    newer.revision = 8
    newer.tracks.removeAll()
    model.adoptLibrary(newer)
    model.adoptLibrary(older)
    model.loaded[.a] = older.tracks[0].id
    #expect(model.library.revision == 8)
    #expect(model.track(.a) == nil)
    await model.finishForShutdown()
}

@Test @MainActor func loadKeepsSynchronousOwnershipAcrossSameRevisionLibraryEdits() async throws {
    let (model, root) = try publicationModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let first = try publicationTrack(1, title: "First")
    let second = try publicationTrack(2, title: "Second")
    model.library.tracks = [first, second]
    let request = model.loadPreparedTrack(trackID: second.id, deck: .b, sourceURL: nil,
        nativeMetadata: nil, nativeLoadOwner: nil)
    #expect(request != nil)
    #expect(model.loaded[.b] == second.id)
    #expect(model.preparingPlayback.contains(.b))
    let token = model.loadIdentity(.b)
    var changed = model.library
    changed.tracks[1].preparation.correctedKey = .init(tonic: 5, mode: .minor)
    model.adoptLibrary(changed)
    #expect(model.loadIdentity(.b) == token)
    #expect(model.track(.b)?.preparation.correctedKey == changed.tracks[1].preparation.correctedKey)
    await model.finishForShutdown()
}
