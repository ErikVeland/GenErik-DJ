import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

private func queueItem(_ id: String, seconds: Double) -> MusicLibraryItem {
    .init(
        source: .init(platform: .iosMusic, persistentID: id), title: id, artist: "Fixture",
        duration: seconds, assetURL: URL(fileURLWithPath: "/dev/null"), availability: .available)
}

@Test(arguments: [[], [60.0], [1141.0], [1141.0, 1140.0, 120.0, 0.0]]) @MainActor
func analysisQueueCompletesBothSongPassesBeforeMixes(durations: [Double]) async {
    let items = durations.enumerated().map { queueItem(String($0.offset), seconds: $0.element) }
    let queue = NativeMusicAnalysisQueue(
        catalog: .init(items: items, playlists: []), tracks: [], loaded: [],
        mediaDirectory: FileManager.default.temporaryDirectory,
        worker: .init(label: "test.analysis-queue"))
    let batches = await queue.prepare()
    let songs = items.filter { $0.duration <= 1140 }.sorted {
        ($0.duration > 0 ? $0.duration : .infinity) < ($1.duration > 0 ? $1.duration : .infinity)
    }.map(\.id)
    let mixes = items.filter { $0.duration > 1140 }.map(\.id)
    var actual: [[String]] = []
    for batch in batches {
        await queue.begin(batch)
        var ids: [String] = []
        while let job = await queue.next() { ids.append(job.id) }
        #expect(ids.count == batch.range.count)
        actual.append(ids)
    }
    #expect(actual == [songs, songs, mixes, mixes].filter { !$0.isEmpty })
    #expect(batches.map(\.pass) == (0..<batches.count).map { $0.isMultiple(of: 2) ? .matching : .structure })
    #expect(
        batches.map(\.isMix)
            == [songs, songs, mixes, mixes].enumerated().compactMap {
                $0.element.isEmpty ? nil : $0.offset >= 2
            })
    await queue.finish()
}

@Test(arguments: [false, true]) @MainActor
func analysisQueueDefersLoadedMix(native: Bool) async throws {
    let song = queueItem("song", seconds: 180)
    let mix = queueItem("mix", seconds: 3600)
    let analysis = AudioAnalysis(
        implementation: "Fixture", configurationID: "fixture", contentSHA256: String(repeating: "a", count: 64),
        sampleRate: 44100, frameCount: (native ? 60 : 3600) * 44100, channelCount: 2, waveformFramesPerBin: 512,
        waveform: [], bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1,
        key: .init(tonic: 0, mode: .major), keyConfidence: 1, chroma: [], timbre: [])
    var track = try Track(title: mix.title, artist: "Fixture", mediaFilename: "mix.wav", analysis: analysis)
    track.nativeLibraryOnly = native
    track.musicLibrarySources = [mix.source]
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    if !native { try Data().write(to: directory.appendingPathComponent(track.mediaFilename)) }
    let queue = NativeMusicAnalysisQueue(
        catalog: .init(items: [mix, song], playlists: []), tracks: [track], loaded: [track.id],
        mediaDirectory: directory,
        worker: .init(label: "test.analysis-queue-loaded-mix"))
    let batches = await queue.prepare()
    #expect(batches.count == 4)
    var ids: [String] = []
    for batch in batches {
        await queue.begin(batch)
        while let job = await queue.next() { ids.append(job.id) }
    }
    let mixID = native ? mix.id : track.id
    #expect(ids == [song.id, song.id, mixID, mixID])
    await queue.finish()
}
