import Foundation
import Testing
@testable import TDJInterface

private enum PlaylistSaveProbeError: Error { case failed }
private actor PlaylistResolutionGate {
    private var completion:CheckedContinuation<[String],Error>?
    private var entered=false
    private var waiters:[CheckedContinuation<Void,Never>]=[]
    func resolve() async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            completion=continuation;entered=true
            for waiter in waiters { waiter.resume() };waiters=[]
        }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func succeed(_ ids:[String]) { completion?.resume(returning:ids);completion=nil }
    func fail(_ error:Error) { completion?.resume(throwing:error);completion=nil }
}

@Test @MainActor func cancelledPlaylistResolutionCannotCommitAfterItReturns() async throws {
    let save=LibraryBrowserPlaylistSave(),gate=PlaylistResolutionGate()
    var commits:[[String]]=[],errors=0
    let pending_task=save.start(resolve:{ try await gate.resolve() },commit:{ commits.append($0) },failed:{ _ in errors+=1 })
    let task=try #require(pending_task)
    await gate.waitUntilEntered();save.cancel()
    #expect(!save.isSaving)
    await gate.succeed(["obsolete"]);await task.value
    #expect(commits.isEmpty && errors == 0 && !save.isSaving)
}

@Test @MainActor func cancelledPlaylistCompletionCannotClearAReopenedSave() async throws {
    let save=LibraryBrowserPlaylistSave(),old=PlaylistResolutionGate(),new=PlaylistResolutionGate()
    var commits:[[String]]=[],errors=0
    let pending_first=save.start(resolve:{ try await old.resolve() },commit:{ commits.append($0) },failed:{ _ in errors+=1 })
    let first=try #require(pending_first)
    await old.waitUntilEntered();save.cancel()
    let pending_second=save.start(resolve:{ try await new.resolve() },commit:{ commits.append($0) },failed:{ _ in errors+=1 })
    let second=try #require(pending_second)
    await new.waitUntilEntered();await old.succeed(["old"]);await first.value
    #expect(commits.isEmpty && errors == 0 && save.isSaving)
    await new.succeed(["new"]);await second.value
    #expect(commits == [["new"]] && errors == 0 && !save.isSaving)
}

@Test @MainActor func obsoletePlaylistFailureDoesNotReportOrClearNewerIntent() async throws {
    let save=LibraryBrowserPlaylistSave(),old=PlaylistResolutionGate(),new=PlaylistResolutionGate()
    var commits:[[String]]=[],errors=0
    let pending_first=save.start(resolve:{ try await old.resolve() },commit:{ commits.append($0) },failed:{ _ in errors+=1 })
    let first=try #require(pending_first)
    await old.waitUntilEntered();save.cancel()
    let pending_second=save.start(resolve:{ try await new.resolve() },commit:{ commits.append($0) },failed:{ _ in errors+=1 })
    let second=try #require(pending_second)
    await new.waitUntilEntered();await old.fail(PlaylistSaveProbeError.failed);await first.value
    #expect(errors == 0 && commits.isEmpty && save.isSaving)
    await new.succeed(["new"]);await second.value
    #expect(commits == [["new"]] && errors == 0 && !save.isSaving)
}

@Test @MainActor func currentPlaylistFailureReportsOnceAndReleasesTheSave() async throws {
    let save=LibraryBrowserPlaylistSave(),gate=PlaylistResolutionGate()
    var errors=0,commits=0
    let pending_task=save.start(resolve:{ try await gate.resolve() },commit:{ _ in commits+=1 },failed:{ _ in errors+=1 })
    let task=try #require(pending_task)
    await gate.waitUntilEntered();await gate.fail(PlaylistSaveProbeError.failed);await task.value
    #expect(errors == 1 && commits == 0 && !save.isSaving)
}

@Test @MainActor func playlistResolutionCancellationIsQuiet() async throws {
    let save=LibraryBrowserPlaylistSave(),gate=PlaylistResolutionGate()
    var errors=0,commits=0
    let pending_task=save.start(resolve:{ try await gate.resolve() },commit:{ _ in commits+=1 },failed:{ _ in errors+=1 })
    let task=try #require(pending_task)
    await gate.waitUntilEntered();await gate.fail(CancellationError());await task.value
    #expect(errors == 0 && commits == 0 && !save.isSaving)
}

@Test @MainActor func pendingPlaylistSaveRejectsDuplicateSubmission() async throws {
    let save=LibraryBrowserPlaylistSave(),gate=PlaylistResolutionGate()
    var commits:[[String]]=[]
    let pending_task=save.start(resolve:{ try await gate.resolve() },commit:{ commits.append($0) },failed:{ _ in })
    let task=try #require(pending_task)
    await gate.waitUntilEntered()
    let duplicate=save.start(resolve:{ ["duplicate"] },commit:{ commits.append($0) },failed:{ _ in })
    #expect(duplicate == nil && save.isSaving)
    await gate.succeed(["first"]);await task.value
    #expect(commits == [["first"]] && !save.isSaving)
}

@Test @MainActor func playlistCommitFailureReportsAndReleasesTheSave() async throws {
    let save=LibraryBrowserPlaylistSave()
    var errors=0
    let pending_task=save.start(resolve:{ ["selected"] },commit:{ _ in throw PlaylistSaveProbeError.failed },failed:{ _ in errors+=1 })
    let task=try #require(pending_task)
    await task.value
    #expect(errors == 1 && !save.isSaving)
}
