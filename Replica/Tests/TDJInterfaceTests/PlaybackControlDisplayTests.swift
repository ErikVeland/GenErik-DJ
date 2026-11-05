import Foundation
import Observation
import Testing

@testable import TDJCore
@testable import TDJInterface

private final class DisplayChangeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func changed() {
        lock.lock()
        count += 1
        lock.unlock()
    }
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

@Test @MainActor func controlDisplayDoesNotPublishAdvancingClockOrMeterPeaks() throws {
    let core = try SampleTransport()
    let asset = try PCMAsset(
        interleavedStereo: (0..<96000).map { Float(($0 / 2 / 128) % 8 + 1) * 0.05 }, sampleRate: 48000)
    let generation = try core.load(asset, deck: .a, grid: nil, synced: false)
    #expect(core.processControlsWhileIdle())
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 128)
    let initial = try #require(core.snapshot())
    let display = PlaybackControlDisplay()
    display.update(initial)
    let identity = display[.a]
    let controlChanges = DisplayChangeCounter()
    withObservationTracking {
        _ = display.masterBPM
        _ = display.crossfader
        _ = display[.a].phase
        _ = display[.a].keylock
        _ = display[.a].loopEnabled
        _ = display[.a].fluxEnabled
        _ = display[.a].mixer.cue
        _ = display[.a].mixer.volume
        _ = display[.a].mixer.low
    } onChange: {
        controlChanges.changed()
    }
    for _ in 0..<4 {
        _ = core.renderOffline(frames: 128)
        display.update(try #require(core.snapshot()))
    }
    #expect(core.snapshot()!.outputFrame > initial.outputFrame)
    #expect(core.snapshot()!.a.mixer.peak != initial.a.mixer.peak)
    #expect(controlChanges.value == 0)
    #expect(display[.a] === identity)
    try core.setMixer(.low, value: 0.8, deck: .a)
    #expect(core.processControlsWhileIdle())
    display.update(try #require(core.snapshot()))
    #expect(display[.a].mixer.low == 0.8)
    #expect(controlChanges.value == 1)
    display.update(nil)
    #expect(display[.a] === identity)
    #expect(display[.a].phase == .empty && display[.a].mixer.low == 1)
}

@Test @MainActor func filterDisplayChangesDoNotInvalidateUnchangedTransportControls() throws {
    let core = try SampleTransport()
    let display = PlaybackControlDisplay()
    display.update(try #require(core.snapshot()))
    let controls = DisplayChangeCounter()
    let filter = DisplayChangeCounter()
    withObservationTracking {
        _ = display[.a].phase
        _ = display[.a].mixer.cue
        _ = display[.a].loopEnabled
    } onChange: {
        controls.changed()
    }
    withObservationTracking {
        _ = display[.a].mixer.filterY
    } onChange: {
        filter.changed()
    }
    try core.setMixer(.filterY, value: 0.37, deck: .a)
    #expect(core.processControlsWhileIdle())
    let snapshot = try #require(core.snapshot())
    display.update(snapshot)
    #expect(display[.a].mixer.filterY == snapshot.a.mixer.filterY)
    #expect(filter.value == 1 && controls.value == 0)
}

@Test(arguments: DeckID.allCases, [false, true]) @MainActor
func deckLayoutDoesNotSubscribeToThePlaybackClock(deck: DeckID, editing: Bool) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let playback = try PlaybackController(offline: true)
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.1, count: 96000), sampleRate: 48000)
    let generation = try playback.core.load(asset, deck: deck, grid: nil, synced: false)
    #expect(playback.core.processControlsWhileIdle())
    try playback.core.play(deck: deck, generation: generation)
    _ = playback.core.renderOffline(frames: 128)
    let initial = try #require(playback.core.snapshot())
    let model = try ReplicaModel(root: root, playback: playback)
    model.playbackSnapshot = initial
    if editing { model.editing.insert(deck) }
    let view = DeckView(model: model, deck: deck, panels: DeckPanelPresentation())
    let layoutChanges = DisplayChangeCounter()
    let timeChanges = DisplayChangeCounter()
    withObservationTracking {
        _ = view.content(size: CGSize(width: 1004, height: 360))
    } onChange: {
        layoutChanges.changed()
    }
    withObservationTracking {
        _ = DeckTimeReadout(model: model, deck: deck, editing: editing).body
    } onChange: {
        timeChanges.changed()
    }
    _ = playback.core.renderOffline(frames: 128)
    let advanced = try #require(playback.core.snapshot())
    #expect(advanced[deck].sourceFrame > initial[deck].sourceFrame)
    model.playbackSnapshot = advanced
    #expect(layoutChanges.value == 0 && timeChanges.value == 1)
}
