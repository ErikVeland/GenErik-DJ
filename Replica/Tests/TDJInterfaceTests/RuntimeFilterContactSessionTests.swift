import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func runtimeModelFilterRejectsInvalidInputAndProducerFailures() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let session = RuntimeFilterContactSession()
    for point in [(Double.nan, 0.2), (0.2, Double.infinity), (-0.1, 0.2), (0.2, 1.1)] {
        #expect(!session.apply(model: model, deck: .a, x: point.0, y: point.1))
    }
    #expect(session.cancelAll(model: model) == 0)
    model.playback.core.processControlsWhileIdle()
    _ = model.playback.core.acknowledgements()
    var full = false
    for _ in 0..<4096 {
        do { try model.playback.core.setMixer(.low, value: 1, deck: .a) } catch TransportError.queueFull {
            full = true
            break
        }
    }
    #expect(full && !session.apply(model: model, deck: .a, x: 0.2, y: 0.3))
    #expect(model.status == TransportError.queueFull.localizedDescription)
    model.playback.core.processControlsWhileIdle()
    _ = model.playback.core.acknowledgements()
    #expect(session.cancelAll(model: model) == 1)
    #expect(session.apply(model: model, deck: .a, x: 0.2, y: 0.3))
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == true)
    _ = session.cancelAll(model: model)
    await model.finishForShutdown()
}

@Test @MainActor func runtimeModelFilterReportsAPartiallyAcceptedAxisBatchAsFailure() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.playback.core.processControlsWhileIdle()
    _ = model.playback.core.acknowledgements()
    // Fill acknowledgements so idle polling cannot drain the producer queue after the first accepted axis.
    for _ in 0..<4 {
        for _ in 0..<127 { try model.playback.core.setMixer(.low, value: 1, deck: .a) }
        model.playback.core.processControlsWhileIdle()
    }
    for _ in 0..<2 { try model.playback.core.setMixer(.low, value: 1, deck: .a) }
    model.playback.core.processControlsWhileIdle()
    for _ in 0..<126 { try model.playback.core.setMixer(.low, value: 1, deck: .a) }
    #expect(!model.filterTouch(x: 0.2, y: 0.3, deck: .a))
    model.playback.core.processControlsWhileIdle()
    _ = model.playback.core.acknowledgements()
    model.refreshPlayback()
    #expect(abs((model.playbackSnapshot?.a.mixer.filterX ?? 0) + 0.6) < 0.000001)
    #expect(model.playbackSnapshot?.a.mixer.filterY == 0 && model.playbackSnapshot?.a.mixer.filterEnabled == false)
    await model.finishForShutdown()
}

@Test @MainActor func runtimeModelFilterKeepsHardwareXAndVerifiesBothSavedResonanceValues() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let session = RuntimeFilterContactSession()
    model.filterLocked = [.a, .b]
    #expect(session.apply(model: model, deck: .a, x: 0.2, y: 0.3))
    model.setMixer(.filterX, value: 0.8, deck: .a)
    #expect(session.apply(model: model, deck: .a, x: 0.2, y: 0.6))
    #expect(model.playbackSnapshot?.a.mixer.filterX == 0.8)
    #expect(session.apply(model: model, deck: .b, x: 0.6, y: 0.4))
    #expect(session.cancelAll(model: model) == 2 && session.cancelAll(model: model) == 0)
    #expect(model.filterLocked == [.a, .b] && session.filtersAreDisabled(model: model))
    await model.finishForShutdown()
    #expect(await session.preferencesMatchSavedState(model: model))
    let file = model.store.root.appendingPathComponent("mixer-preferences.json")
    var wrong = try MixerPreferences.load(from: file)
    wrong.filterResonanceB = 0
    try wrong.save(to: file)
    #expect(!(await session.preferencesMatchSavedState(model: model)))
    try Data("invalid".utf8).write(to: file)
    #expect(!(await session.preferencesMatchSavedState(model: model)))
    try FileManager.default.removeItem(at: file)
    #expect(!(await session.preferencesMatchSavedState(model: model)))
}

@Test @MainActor func runtimeModelFilterMatchesDirectActiveFilterAudioAndDiffersFromBypass() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let reference = try ReplicaModel(
        root: root.appendingPathComponent("Reference"), playback: PlaybackController(offline: true))
    let model = try ReplicaModel(
        root: root.appendingPathComponent("Model"), playback: PlaybackController(offline: true))
    let dry = try SampleTransport()
    let session = RuntimeFilterContactSession()
    let samples = (0..<8192).flatMap { i -> [Float] in [Float(i % 97) / 200, -Float(i % 71) / 200] }
    for core in [reference.playback.core, model.playback.core, dry] {
        for deck in DeckID.primary {
            let asset = try PCMAsset(interleavedStereo: samples, sampleRate: 48000)
            let generation = try core.load(asset, deck: deck, grid: nil, synced: false)
            core.processControlsWhileIdle()
            try core.play(deck: deck, generation: generation)
        }
    }
    var differs = false
    for point in [(0.25, 0.75), (0.8, 0.4), (0.8, 0.2)] {
        for deck in DeckID.primary {
            try reference.playback.setMixer(.filterX, value: point.0 * 2 - 1, deck: deck)
            try reference.playback.setMixer(.filterY, value: 1 - point.1, deck: deck)
            try reference.playback.setMixer(.filterEnabled, value: 1, deck: deck)
            #expect(session.apply(model: model, deck: deck, x: point.0, y: point.1))
        }
        for _ in 0..<4 {
            let a = reference.playback.core.renderOffline(frames: 256)
            let b = model.playback.core.renderOffline(frames: 256)
            let c = dry.renderOffline(frames: 256)
            #expect(
                a.left.map(\.bitPattern) == b.left.map(\.bitPattern)
                    && a.right.map(\.bitPattern) == b.right.map(\.bitPattern))
            differs = differs || b.left.map(\.bitPattern) != c.left.map(\.bitPattern)
            reference.refreshPlayback()
            model.refreshPlayback()
        }
    }
    #expect(differs && session.cancelAll(model: model) == 2)
    await reference.finishForShutdown()
    await model.finishForShutdown()
}

@Test @MainActor func runtimeModelFilterReportsFailedCancellationEvenIfShutdownLaterStopsPlayback() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let session = RuntimeFilterContactSession()
    for deck in DeckID.primary { #expect(session.apply(model: model, deck: deck, x: 0.3, y: 0.4)) }
    var full = false
    for _ in 0..<4096 {
        do { try model.playback.core.setMixer(.low, value: 1, deck: .a) } catch TransportError.queueFull {
            full = true
            break
        }
    }
    #expect(full && session.cancelAll(model: model) == 2 && session.cancellationFailures == 2)
    model.playback.core.processControlsWhileIdle()
    _ = model.playback.core.acknowledgements()
    await model.finishForShutdown()
    #expect(session.cancellationFailures == 2)
}
