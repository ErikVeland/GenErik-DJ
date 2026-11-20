import Combine
import Foundation
import Observation
import Testing

@testable import TDJCore
@testable import TDJInterface

private final class BrowserFreezeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}

@MainActor private func browserFreezeFixture() async throws -> (ReplicaModel, URL) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    // Use the generator's known grids. This check does not test music analysis.
    for (name, frames, bpm) in [("clock-a-120.wav", Int64(705600), 120.0), ("clock-b-128.wav", Int64(661500), 128.0)] {
        let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/" + name)
        try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent(name))
        let analysis = AudioAnalysis(
            implementation: "browser-freeze-fixture", configurationID: "fixture",
            contentSHA256: try AudioAnalyzer.sha256(url: source), sampleRate: 44100, frameCount: frames,
            channelCount: 2, waveformFramesPerBin: 441, waveform: [], bpm: bpm, beatAnchorFrame: 0,
            tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        library.tracks.append(try Track(title: name, mediaFilename: name, analysis: analysis))
    }
    try store.save(library)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true), automaticTraktorSources: [])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    return (model, root)
}

@Suite(.serialized) struct BrowserFreezeRegressionTests {
    @Test @MainActor func observationControlDetectsTheLegacyMutationPath() async throws {
        let (model, root) = try await browserFreezeFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let cancelled = BrowserFreezeCounter()
        withObservationTracking {
            model.access(keyPath: \.browserPresentationID)
        } onChange: { cancelled.increment() }
        model.showSuggestions(destination: .b)
        #expect(cancelled.value == 0)
        // Recreate the old setter's notification to prove that the observer is active.
        model.withMutation(keyPath: \.browserPresentationID) {}
        #expect(cancelled.value == 1)
        await model.finishForShutdown()
    }

    @Test @MainActor func repeatedRecommendationsBypassPendingObserversAndPreserveOfflineAudio() async throws {
        let (model, root) = try await browserFreezeFixture()
        let (reference, referenceRoot) = try await browserFreezeFixture()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: referenceRoot)
        }
        let cancelled = BrowserFreezeCounter()
        // Represent pending reads from a long session without changing the app's request path.
        for _ in 0..<10_000 {
            withObservationTracking {
                model.access(keyPath: \.browserPresentationID)
            } onChange: { cancelled.increment() }
        }
        let delivered = BrowserFreezeCounter()
        let incoherent = BrowserFreezeCounter()
        let subscription = model.browserPresentationRequests.sink { request in
            delivered.increment()
            if model.suggestionDestination != .b || !model.browserVisible || !model.browserPresentationExpands
                || request != model.browserPresentationID
            { incoherent.increment() }
        }
        defer { subscription.cancel() }
        let loaded = model.loaded
        model.pressPlay(deck: .a)
        reference.pressPlay(deck: .a)
        await model.flushTransportRequests()
        await reference.flushTransportRequests()
        let sync = try #require(model.playback.core.snapshot()).a.synced
        var maximumDifference: Float = 0
        var referencePeak: Float = 0
        var allFinite = true
        var requests = Set<UUID>()
        let clock = ContinuousClock()
        var requestTime = Duration.zero
        for index in 0..<128 {
            if index.isMultiple(of: 2) { model.browserVisible = false }
            let start = clock.now
            model.showSuggestions(destination: .b)
            requestTime += start.duration(to: clock.now)
            requests.insert(model.browserPresentationID)
            #expect(model.suggestionDestination == .b && model.browserVisible && model.browserPresentationExpands)
            let actual = model.playback.core.renderOffline(frames: 512)
            let expected = reference.playback.core.renderOffline(frames: 512)
            #expect(actual.left.count == expected.left.count && actual.right.count == expected.right.count)
            for (a, b) in zip(actual.left + actual.right, expected.left + expected.right) {
                allFinite = allFinite && a.isFinite && b.isFinite
                maximumDifference = max(maximumDifference, abs(a - b))
                referencePeak = max(referencePeak, abs(b))
            }
            let state = try #require(model.playback.core.snapshot())
            let referenceState = try #require(reference.playback.core.snapshot())
            #expect(state.a.phase == referenceState.a.phase)
            #expect(state.a.sourceFrame == referenceState.a.sourceFrame)
            #expect(state.a.synced == sync)
            await Task.yield()
        }
        await model.flushSuggestions()
        #expect(model.suggestions.count == 1)
        #expect(!loaded.values.contains(try #require(model.suggestions.first).id))
        #expect(delivered.value == 128 && requests.count == 128)
        #expect(cancelled.value == 0 && incoherent.value == 0)
        #expect(model.loaded == loaded)
        #expect(allFinite && referencePeak > 0)
        #expect(maximumDifference == 0)
        print("R428: 10000 pending observers, 128 requests, request time \(requestTime), maximum audio difference \(maximumDifference)")
        await model.finishForShutdown()
        await reference.finishForShutdown()
    }
}
