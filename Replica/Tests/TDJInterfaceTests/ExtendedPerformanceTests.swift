import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface

@Test @MainActor func extendedPerformanceKeepsOptionalWorkPausedBetweenTracks() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(model.canSyncCloud)
    model.storeAccess.beginPerformance()
    model.refreshPlayback()
    #expect(!model.canSyncCloud)
    #expect(WaveformWork.isPaused(model.playback.core))
    let background = model.beginBackgroundLibraryAnalysis { _, _ in }
    #expect(background == nil)
    if let background { model.endBackgroundLibraryAnalysis(background) }
    model.endPerformance()
    #expect(model.canSyncCloud)
    #expect(!WaveformWork.isPaused(model.playback.core))
}

@Test @MainActor func extendedPerformanceDoesNotRewriteUnchangedAccessState() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let access = StoreAccess(root: root, developerAccess: true)
    access.beginPerformance(controllerInput: true)
    let file = root.appendingPathComponent("access-performance.json")
    let marker = Date(timeIntervalSince1970: 1_000_000)
    try FileManager.default.setAttributes([.modificationDate: marker], ofItemAtPath: file.path)
    for _ in 0..<100 { access.beginPerformance(controllerInput: true) }
    let modified = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
    #expect(modified == marker)
    access.endPerformance()
}

@Test @MainActor func extendedRecordingPreparationWaitsForPerformanceEnd() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.toggleRecording()
    _ = model.playback.core.renderOffline(frames: 1024)
    await model.toggleRecording()
    let recording = try #require(model.recordings.first)
    #expect(model.storeAccess.hasActivePerformance)
    await model.loadRecording(recording, deck: .b)
    #expect(model.library.tracks.isEmpty)
    #expect(model.loaded[.b] == nil)
    #expect(FileManager.default.fileExists(atPath: recording.path))
    await model.finishForShutdown()
}

@Test @MainActor func idleRelaunchAllowsPreparationWithSavedPerformanceTiming() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    StoreAccess(root: root).beginPerformance()
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(model.storeAccess.hasPerformanceTiming)
    #expect(!model.storeAccess.hasActivePerformance)
    #expect(model.canSyncCloud)
    model.storeAccess.beginPerformance()
    model.refreshPlayback()
    #expect(!model.canSyncCloud)
}
