import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@MainActor private final class CleanupLibraryProvider: LocalMusicLibraryProviding {
    enum Mode { case failureAfterFirst, cancellationAfterFirst, external, invalidAudio }
    let mode: Mode
    let source: URL
    let items: [MusicLibraryItem]
    var directory: URL?
    var preparedFile: URL?
    var firstFileWasCleanedBeforeNextPreparation=false
    init(source: URL, mode: Mode) {
        self.source=source;self.mode=mode
        items=(0..<(mode == .external || mode == .invalidAudio ? 1:2)).map {
            MusicLibraryItem(source:.init(platform:.iosMusic,persistentID:"cleanup-\($0)"),title:"Cleanup \($0)",artist:"Fixture",assetURL:source,availability:.available)
        }
    }
    func catalog() async throws -> MusicLibraryCatalog { .init(items:items,playlists:[]) }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        self.directory=directory
        if item.id == items.first?.id {
            if mode == .external { return .init(url:source,metadata:.init(item:item),temporary:true) }
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let file=directory.appendingPathComponent("prepared.wav");preparedFile=file
            if mode == .invalidAudio { try Data("invalid audio".utf8).write(to:file) }
            else { try FileManager.default.copyItem(at:source,to:file) }
            return .init(url:file,metadata:.init(item:item),temporary:true)
        }
        firstFileWasCleanedBeforeNextPreparation = preparedFile.map { !FileManager.default.fileExists(atPath:$0.path) } ?? false
        try Data("unfinished preparation".utf8).write(to:directory.appendingPathComponent("partial.wav"))
        if mode == .cancellationAfterFirst { throw CancellationError() }
        throw MusicLibraryError.decoding("Expected preparation failure")
    }
}

@MainActor private func cleanupFixture(_ mode: CleanupLibraryProvider.Mode) throws -> (ReplicaModel,CleanupLibraryProvider,URL) {
    var workspace=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { workspace.deleteLastPathComponent() }
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let original=root.appendingPathComponent("original.wav")
    try FileManager.default.copyItem(at:workspace.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav"),to:original)
    let provider=CleanupLibraryProvider(source:original,mode:mode)
    return (try ReplicaModel(root:root.appendingPathComponent("Workspace"),playback:PlaybackController(offline:true),musicLibraryProvider:provider),provider,root)
}

@Test(arguments:[false,true]) @MainActor
func temporaryMusicCleanupFinishesBeforeFailureOrCancellationReturns(cancel: Bool) async throws {
    let (model,provider,root)=try cleanupFixture(cancel ? .cancellationAfterFirst:.failureAfterFirst)
    defer { try? FileManager.default.removeItem(at:root) }
    let hash=try AudioAnalyzer.sha256(url:provider.source)
    await model.refreshMusicLibrary()
    await model.importMusicLibraryItems(Set(provider.items.map(\.id)))
    let directory=try #require(provider.directory)
    #expect(provider.firstFileWasCleanedBeforeNextPreparation)
    #expect(!FileManager.default.fileExists(atPath:directory.path))
    #expect(!model.importing && model.library.tracks.count == 1)
    #expect(model.musicLibraryFailures.count == (cancel ? 0:1))
    if cancel { #expect(model.musicLibraryProgress == "Stopped. Prepared songs were retained.") }
    #expect(try AudioAnalyzer.sha256(url:provider.source) == hash)
    await model.finishForShutdown()
}

@Test @MainActor func musicCleanupNeverDeletesAnExternalSourceMarkedTemporary() async throws {
    let (model,provider,root)=try cleanupFixture(.external)
    defer { try? FileManager.default.removeItem(at:root) }
    let hash=try AudioAnalyzer.sha256(url:provider.source)
    await model.refreshMusicLibrary();await model.importMusicLibraryItems(Set(provider.items.map(\.id)))
    #expect(model.library.tracks.count == 1 && model.musicLibraryFailures.isEmpty && !model.importing)
    #expect(try AudioAnalyzer.sha256(url:provider.source) == hash)
    await model.finishForShutdown()
}

@Test @MainActor func failedImportedAudioIsRemovedBeforeBatchCompletion() async throws {
    let (model,provider,root)=try cleanupFixture(.invalidAudio)
    defer { try? FileManager.default.removeItem(at:root) }
    await model.refreshMusicLibrary();await model.importMusicLibraryItems(Set(provider.items.map(\.id)))
    #expect(model.library.tracks.isEmpty && model.musicLibraryFailures.count == 1 && !model.importing)
    #expect(!FileManager.default.fileExists(atPath:try #require(provider.preparedFile).path))
    #expect(!FileManager.default.fileExists(atPath:try #require(provider.directory).path))
    await model.finishForShutdown()
}
