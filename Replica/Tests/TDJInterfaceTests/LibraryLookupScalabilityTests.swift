import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface

private func scalabilityTrack(_ number: Int) throws -> Track {
    let identity = String(format: "%064x", number)
    let analysis = AudioAnalysis(implementation: "lookup-scale-test", configurationID: "lookup-scale-test",
        contentSHA256: identity, sampleRate: 48000, frameCount: 48000, channelCount: 2,
        waveformFramesPerBin: 512, waveform: [], bpm: 120, beatAnchorFrame: 0,
        tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    return try Track(title: "Track \(number)", mediaFilename: "lookup-scale.wav", analysis: analysis)
}

private func scalabilitySnapshots(root: URL) async throws -> (LibrarySnapshot, LibrarySnapshot) {
    try await Task.detached(priority: .background) {
        let store = try WorkspaceStore(root: root)
        var large = LibrarySnapshot()
        large.tracks = try (1...115000).map(scalabilityTrack)
        var small = LibrarySnapshot()
        small.tracks = Array(large.tracks.suffix(1024))
        return (try store.metadataSnapshot(small), try store.metadataSnapshot(large))
    }.value
}

private func elapsedMilliseconds(_ duration: Duration) -> Double {
    let parts = duration.components
    return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
}

@Test @MainActor func lateLibraryAdoptionHasBoundedLookupGrowth() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let (small, large) = try await scalabilitySnapshots(root: root.appendingPathComponent("setup"))
    let target = try #require(large.tracks.last?.id)
    let model = try ReplicaModel(root: root.appendingPathComponent("model"), playback: PlaybackController(offline: true))
    model.library = small
    let request = model.loadPreparedTrack(trackID: target, deck: .a, sourceURL: nil,
        nativeMetadata: nil, nativeLoadOwner: nil)
    #expect(request != nil)
    let clock = ContinuousClock()
    func sample(_ snapshot: LibrarySnapshot) -> Double {
        let start = clock.now
        for _ in 0..<32 { model.adoptLibrary(snapshot) }
        return elapsedMilliseconds(start.duration(to: clock.now))
    }
    _ = sample(small)
    var smallTimes: [Double] = [], largeTimes: [Double] = []
    for _ in 0..<3 { smallTimes.append(sample(small)); largeTimes.append(sample(large)) }
    let smallMedian = smallTimes.sorted()[1]
    let largeMedian = largeTimes.sorted()[1]
    let ratio = largeMedian / max(smallMedian, 0.001)
    print("LOOKUP_SCALABILITY adoption small=\(smallTimes) large=\(largeTimes) growth=\(ratio) iterations=32 diagnosticOnly=true audioAcceptance=false")
    #expect(ratio < 10, "Lookup growth must stay bounded when the library grows from 1024 to 115000 tracks. This is a batch scalability check, not the 20 ms audio/control acceptance test.")
    #expect(model.loaded[.a] == target)
    await model.finishForShutdown()
}

@Test @MainActor func lateLibraryLoadHasBoundedLookupGrowth() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let (small, large) = try await scalabilitySnapshots(root: root.appendingPathComponent("setup"))
    let target = try #require(large.tracks.last?.id)
    let clock = ContinuousClock()
    func sample(_ snapshot: LibrarySnapshot, name: String) async throws -> Double {
        let model = try ReplicaModel(root: root.appendingPathComponent(name), playback: PlaybackController(offline: true))
        model.library = snapshot
        let start = clock.now
        for _ in 0..<32 {
            model.load(trackID: target, deck: .b)
        }
        let elapsed = elapsedMilliseconds(start.duration(to: clock.now))
        #expect(model.loaded[.b] == target)
        #expect(model.preparingPlayback.contains(.b))
        await model.finishForShutdown()
        return elapsed
    }
    var smallTimes: [Double] = [], largeTimes: [Double] = []
    for round in 0..<3 {
        smallTimes.append(try await sample(small, name: "small-\(round)"))
        largeTimes.append(try await sample(large, name: "large-\(round)"))
    }
    let ratio = largeTimes.sorted()[1] / max(smallTimes.sorted()[1], 0.001)
    print("LOOKUP_SCALABILITY load small=\(smallTimes) large=\(largeTimes) growth=\(ratio) iterations=32 diagnosticOnly=true audioAcceptance=false")
    #expect(ratio < 10, "LOAD lookup growth must stay bounded across library sizes. This batch scalability check does not replace the unchanged 20 ms audio/control test.")
}
