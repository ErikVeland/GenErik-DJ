import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface

@Test @MainActor func cloudPreparationDoesNotStartDuringLoadingOrAnotherCloudOperation() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(model.canSyncCloud)
    model.preparingPlayback.insert(.a)
    #expect(!model.canSyncCloud)
    model.startCloudSync()
    #expect(model.cloudTask == nil)
    model.preparingPlayback.remove(.a)
    model.cloudBusy = true
    #expect(!model.canSyncCloud)
    model.startCloudSync()
    #expect(model.cloudTask == nil)
}

@Test @MainActor func startingPlaybackCancelsPendingCloudWorkWithoutWaiting() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let work = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
    model.cloudTask = work
    model.pressPlay(deck: .a)
    #expect(work.isCancelled)
}

@Test @MainActor func cloudPreparationStopsWhenControllerPlaybackStarts() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let playback = try PlaybackController(offline: true)
    let model = try ReplicaModel(root: root, playback: playback)
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.1, count: 96000), sampleRate: 48000)
    let generation = try playback.core.load(asset, deck: .a, grid: nil, synced: false)
    #expect(playback.core.processControlsWhileIdle())
    let work = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
    model.cloudTask = work
    try playback.core.play(deck: .a, generation: generation)
    _ = playback.core.renderOffline(frames: 128)
    #expect(!model.canSyncCloud)
    model.refreshPlayback()
    #expect(work.isCancelled)
}
