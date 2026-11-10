import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func runtimeModelFXRejectsInvalidRequestsAndReportsProducerQueueFailure() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    for bad in [
        (0, -1, 0.2, 0.3), (PerformanceEffect.supportedCount, 0, 0.2, 0.3), (0, 0, Double.nan, 0.3),
        (0, 0, 0.2, Double.infinity), (0, 0, 1.1, 0.3), (0, 0, 0.2, -0.1),
    ] {
        #expect(
            !model.applyRuntimeEffectControl(
                kind: bad.0, slot: bad.1, x: bad.2, y: bad.3, enabled: true, deck: .a, persist: true))
    }
    #expect(model.effects.isEmpty && model.effectDisplay[.a, 0].x == 0.5)
    var full = false
    for _ in 0..<4096 {
        do { try model.playback.core.setMixer(.low, value: 1, deck: .a) } catch TransportError.queueFull {
            full = true
            break
        }
    }
    #expect(full)
    #expect(!model.applyRuntimeEffectControl(kind: 2, slot: 0, x: 0.2, y: 0.3, enabled: true, deck: .a, persist: true))
    #expect(model.effects.isEmpty && !model.effectDisplay[.a, 0].enabled)
    #expect(model.status == TransportError.queueFull.localizedDescription)
    model.playback.core.processControlsWhileIdle()
    _ = model.playback.core.acknowledgements()
    #expect(model.applyRuntimeEffectControl(kind: 2, slot: 0, x: 0.2, y: 0.3, enabled: true, deck: .a, persist: true))
    #expect(model.effectDisplay[.a, 0].kind == 2 && model.effectDisplay[.a, 0].enabled)
    await model.finishForShutdown()
    #expect(await model.runtimeEffectsMatchSavedState())
}

@Test @MainActor func runtimeModelFXValidatesTheLatestSavedFieldsAndRetainsLocks() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.setEffect(.init(kind: 1, x: 0.4, y: 0.6, enabled: true, locked: true), slot: 1, deck: .b)
    #expect(model.applyRuntimeEffectControl(kind: 3, slot: 1, x: 0.8, y: 0.2, enabled: false, deck: .b, persist: true))
    #expect(model.effects[.b]?[1]?.locked == true && model.effectDisplay[.b, 1].locked)
    #expect(model.effectDisplay[.b, 1].x == 0.8 && !model.effectDisplay[.b, 1].enabled)
    model.status = "unchanged"
    #expect(!model.setEffect(.init(kind: -1), slot: 1, deck: .b))
    #expect(model.status != "unchanged" && model.effectDisplay[.b, 1].kind == 3)
    await model.finishForShutdown()
    #expect(await model.runtimeEffectsMatchSavedState())
    let file = model.store.root.appendingPathComponent("effects.json")
    let wrong: [DeckID: [Int: EffectControl]] = [.b: [1: .init(kind: 3, x: 0.7, y: 0.2, enabled: false, locked: true)]]
    try JSONEncoder().encode(wrong).write(to: file, options: .atomic)
    #expect(!(await model.runtimeEffectsMatchSavedState()))
    let wrongSync: [DeckID: [Int: EffectControl]] = [
        .b: [1: .init(kind: 3, x: 0.8, y: 0.2, enabled: false, locked: true, delaySync: false)]
    ]
    try JSONEncoder().encode(wrongSync).write(to: file, options: .atomic)
    #expect(!(await model.runtimeEffectsMatchSavedState()))
    try Data("invalid".utf8).write(to: file, options: .atomic)
    #expect(!(await model.runtimeEffectsMatchSavedState()))
    try FileManager.default.removeItem(at: file)
    #expect(!(await model.runtimeEffectsMatchSavedState()))
}

@Test @MainActor func runtimeModelFXPreservesControllerAudioAcrossEveryEffectKind() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let reference = try ReplicaModel(
        root: root.appendingPathComponent("Reference"), playback: PlaybackController(offline: true))
    let exercised = try ReplicaModel(
        root: root.appendingPathComponent("Model"), playback: PlaybackController(offline: true))
    let samples = (0..<8192).flatMap { i -> [Float] in [Float(i % 97) / 200, -Float(i % 71) / 200] }
    func setup(_ model: ReplicaModel) throws {
        for deck in DeckID.primary {
            let asset = try PCMAsset(interleavedStereo: samples, sampleRate: 48000)
            let generation = try model.playback.core.load(asset, deck: deck, grid: nil, synced: false)
            model.playback.core.processControlsWhileIdle()
            try model.playback.core.play(deck: deck, generation: generation)
        }
    }
    try setup(reference)
    try setup(exercised)
    var nonzero = false
    for batch in 0..<22 {
        for deck in DeckID.primary {
            for slot in 0..<3 {
                let kind = (batch + slot) % PerformanceEffect.supportedCount
                let x = 0.2 + Double(batch % 5) * 0.1
                try reference.playback.setEffect(kind, slot: slot, x: x, y: 0.3, enabled: true, deck: deck)
                #expect(
                    exercised.applyRuntimeEffectControl(
                        kind: kind, slot: slot, x: x, y: 0.3, enabled: true, deck: deck, persist: batch % 5 == 4))
            }
        }
        reference.refreshPlayback()
        exercised.refreshPlayback()
        let a = reference.playback.core.renderOffline(frames: 256)
        let b = exercised.playback.core.renderOffline(frames: 256)
        #expect(a.left.map(\.bitPattern) == b.left.map(\.bitPattern))
        #expect(a.right.map(\.bitPattern) == b.right.map(\.bitPattern))
        nonzero = nonzero || a.left.contains { abs($0) > 0.000001 }
    }
    #expect(nonzero && exercised.playback.rejectedCommandCount == 0)
    await reference.finishForShutdown()
    await exercised.finishForShutdown()
    #expect(await exercised.runtimeEffectsMatchSavedState())
}
