import Foundation
import Testing
@testable import TDJCore
import TDJInterface

@Test @MainActor func backgroundPreparationPreservesPlaybackAndRecording() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let core=model.playback.core
    let generation=try core.load(PCMAsset(interleavedStereo:Array(repeating:Float(0.1),count:12000),sampleRate:48000),deck:.a,grid:nil,synced:false)
    try core.play(deck:.a,generation:generation)
    await model.toggleRecording()
    _=core.renderOffline(frames:1024)
    await model.prepareForBackground()
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(model.playback.isRecording)
    let audio=core.renderOffline(frames:1024)
    #expect(audio.left.allSatisfy { abs($0-0.05)<0.000001 })
    #expect(core.snapshot()?.a.sourceFrame == 2048)
    await model.finishForShutdown()
    #expect(!model.playback.isRecording)
    #expect(SetRecorder.savedRecordings(in:model.recordingsDirectory).count == 1)
}

@Test @MainActor func shutdownDrainsRecordingAndPendingPreferences() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    model.setMixer(.filterY,value:0.65,deck:.a)
    var lists=CollectionPlaylists()
    try lists.add(trackIDs:[],name:"Saved at shutdown")
    model.persistCollectionPlaylists(lists)
    await model.toggleRecording()
    _=model.playback.core.renderOffline(frames:2048)
    async let first: Void=model.playback.finishRecording()
    async let second: Void=model.finishForShutdown()
    _=await (first,second)
    #expect(!model.playback.isRecording && !model.playback.recordingFinishing)
    #expect(SetRecorder.savedRecordings(in:model.recordingsDirectory).count == 1)
    let restored=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    #expect(restored.playbackSnapshot?.a.mixer.filterY == 0.65)
    #expect(try CollectionPlaylists.load(from:root.appendingPathComponent("collection-playlists.json")) == lists)
}

@Test @MainActor func recordingWorkflowSavesAndRediscoversSets() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.toggleRecording()
    #expect(model.isRecording)
    _ = model.playback.core.renderOffline(frames: 1000)
    await model.toggleRecording()
    #expect(!model.isRecording)
    #expect(model.recordings.count == 1)
    let restarted = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(restarted.recordings == model.recordings)
    await model.toggleRecording()
    _ = model.playback.core.renderOffline(frames: 500)
    model.stopAudio()
    // Stop finalises on the file queue without blocking playback controls.
    for _ in 0..<100 {
        await Task.yield()
        try await Task.sleep(for: .milliseconds(5))
        model.refreshPlayback()
        if !model.isRecording && !model.recordingFinishing { break }
    }
    #expect(!model.isRecording)
    #expect(!model.recordingFinishing)
    await model.flushRecordingList()
    #expect(model.recordings.count == 2)
    #expect(model.status.isEmpty)
}

@Test @MainActor func savedRecordingCanBePreparedAndLoadedIntoADeck() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    await model.toggleRecording()
    _=model.playback.core.renderOffline(frames:48000)
    await model.toggleRecording()
    let recording=try #require(model.recordings.first)
    await model.loadRecording(recording,deck:.b)
    await model.flushWaveforms()
    #expect(model.library.tracks.count == 1)
    #expect(model.loaded[.b] == model.library.tracks.first?.id)
    #expect(model.playbackSnapshot?.b.phase == .ready)
    #expect(model.library.tracks.first?.analysis.waveform.isEmpty == true)
    #expect(model.track(.b)?.analysis.waveform.isEmpty == false)
    #expect(FileManager.default.fileExists(atPath:recording.path))
}

@Test @MainActor func filterResonancePersistsAndEQResetPreservesVolume() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    model.setMixer(.filterY,value:0.7,deck:.a)
    model.setMixer(.filterY,value:0.3,deck:.b)
    model.setMixer(.volume,value:0.4,deck:.a)
    model.setMixer(.low,value:0.2,deck:.a)
    model.resetEQ(deck:.a)
    #expect(model.playbackSnapshot?.a.mixer.volume == 0.4)
    #expect(model.playbackSnapshot?.a.mixer.low == 1)
    model.stopAudio()
    await model.flushPreferenceWrites()
    let restarted=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    #expect(restarted.playbackSnapshot?.a.mixer.filterY == 0.7)
    #expect(restarted.playbackSnapshot?.b.mixer.filterY == 0.3)
}

@Test @MainActor func recordingListRefreshPublishesLatestCompletedFiles() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model = try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let directory = model.recordingsDirectory
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    try Data().write(to:directory.appendingPathComponent("Set-1.aiff"))
    try Data().write(to:directory.appendingPathComponent("Set-2.incomplete.aiff"))
    model.refreshRecordings()
    #expect(model.recordingsRefreshing)
    await model.flushRecordingList()
    #expect(model.recordings.map(\.lastPathComponent) == ["Set-1.aiff"])
    try Data().write(to:directory.appendingPathComponent("Set-3.aiff"))
    model.refreshRecordings(); model.refreshRecordings()
    await model.flushRecordingList()
    #expect(model.recordings.map(\.lastPathComponent) == ["Set-3.aiff","Set-1.aiff"])
    #expect(!model.recordingsRefreshing)
}

@Test @MainActor func recordingOverflowFinalizesFailureWithoutStoppingThePlayingDeck() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model = try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let core = model.playback.core
    let asset = try PCMAsset(interleavedStereo:Array(repeating:Float(0.1),count:12000),sampleRate:48000)
    let generation = try core.load(asset,deck:.a,grid:nil,synced:false)
    try core.play(deck:.a,generation:generation)
    await model.toggleRecording()
    _ = core.renderOffline(frames:512)
    let tooLarge = [Float](repeating:0.1,count:480001)
    tooLarge.withUnsafeBufferPointer { core.recording.capture(frames:480001,left:$0.baseAddress!,right:$0.baseAddress!) }
    #expect(core.recording.hasFailed)
    model.refreshPlayback()
    await model.playback.finishRecording()
    model.refreshPlayback(); await model.flushRecordingList()
    #expect(!model.playback.isRecording)
    #expect(model.playback.recordingError?.contains("lost frames") == true)
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(model.recordings.isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath:model.recordingsDirectory.path).contains { $0.hasSuffix(".incomplete.aiff") })
    await model.finishForShutdown()
}

@Test @MainActor func recordingUsesConfiguredFilesDirectoryAndLocation() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = root.appendingPathComponent("Workspace")
    let recordings = root.appendingPathComponent("Documents/Recordings")
    let model = try ReplicaModel(root: workspace, playback: PlaybackController(offline: true), recordingsDirectory: recordings)
    model.recordingLocation = "Brisbane"
    await model.toggleRecording()
    _ = model.playback.core.renderOffline(frames: 1024)
    await model.toggleRecording()
    let file = try #require(model.recordings.first)
    #expect(file.deletingLastPathComponent().resolvingSymlinksInPath().path == recordings.resolvingSymlinksInPath().path)
    #expect(file.lastPathComponent.hasPrefix("Brisbane - "))
    #expect(FileManager.default.fileExists(atPath: file.deletingPathExtension().appendingPathExtension("txt").path))
}

@Test @MainActor func recordingTracklistsUseTheBackgroundListSnapshot() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let directory = model.recordingsDirectory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let audio = directory.appendingPathComponent("Saved.aiff")
    let sidecar = directory.appendingPathComponent("Saved.txt")
    try Data().write(to: audio)
    try Data().write(to: sidecar)
    try Data().write(to: directory.appendingPathComponent("Legacy.aiff"))
    try FileManager.default.createDirectory(at: directory.appendingPathComponent("Legacy.txt"), withIntermediateDirectories: false)
    try Data().write(to: directory.appendingPathComponent("Hidden.incomplete.aiff"))
    try Data().write(to: directory.appendingPathComponent("Hidden.incomplete.txt"))
    model.refreshRecordings()
    await model.flushRecordingList()
    #expect(model.recordings.map(\.lastPathComponent) == ["Saved.aiff", "Legacy.aiff"])
    let legacy = try #require(model.recordings.last)
    #expect(model.recordingTracklist(for: legacy) == nil)
    let listed = try #require(model.recordings.first)
    #expect(model.recordingTracklist(for: listed)?.lastPathComponent == sidecar.lastPathComponent)
    try FileManager.default.removeItem(at: sidecar)
    #expect(model.recordingTracklist(for: listed) != nil)
    model.refreshRecordings()
    await model.flushRecordingList()
    #expect(model.recordingTracklist(for: listed) == nil)
    try Data().write(to: sidecar)
    try FileManager.default.removeItem(at: audio)
    model.refreshRecordings()
    await model.flushRecordingList()
    #expect(model.recordings.map(\.lastPathComponent) == ["Legacy.aiff"])
    #expect(model.recordingTracklist(for: listed) == nil)
    await model.finishForShutdown()
}
