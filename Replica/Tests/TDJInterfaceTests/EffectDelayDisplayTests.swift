import Foundation
import Observation
import TDJCore
import Testing

@testable import TDJInterface

private final class DelayDisplayChanges: @unchecked Sendable {
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

@Test @MainActor func delayDisplayPreservesLegacySyncAndPublishesOnlyVisibleTimeChanges() {
    let slot = EffectSlotDisplay()
    let changes = DelayDisplayChanges()
    slot.publish(.init(kind: 0, x: 0.3, y: 0.5, enabled: true, locked: false))
    #expect(slot.delaySync == nil && slot.delayBeatStep == 1)
    withObservationTracking {
        _ = EffectDelayDisplayValue(slot)
    } onChange: {
        changes.changed()
    }
    for step in 0..<1000 {
        slot.publish(.init(kind: 0, x: 0.3 + Double(step) / 20000, y: 0.7, enabled: true, locked: false))
    }
    #expect(changes.value == 0 && slot.delayBeatStep == 1)
    slot.publish(.init(kind: 0, x: 0.4, y: 0.7, enabled: true, locked: false))
    #expect(changes.value == 1 && slot.delayBeatStep == 2)
    slot.publish(.init(kind: 0, x: 0, y: 0.7, enabled: true, locked: false, delaySync: false))
    #expect(slot.delaySync == false && slot.delayMilliseconds == 25)
    slot.publish(.init(kind: 0, x: 1, y: 0.7, enabled: true, locked: false, delaySync: false))
    #expect(slot.delayMilliseconds == 2000)
    slot.publish(.init(kind: 0, x: 1, y: 0.7, enabled: true, locked: false, delaySync: true))
    #expect(slot.delayBeatStep == 4 && slot.delaySync == true)
}

@Test @MainActor func hiddenDelayReadoutDoesNotObserveSweepsAndCapturesCurrentValuesOnOpen() {
    let slot = EffectSlotDisplay()
    let changes = DelayDisplayChanges()
    var cache = MixerPaneDisplayCache(EffectDelayDisplayValue(slot))
    var reads = 0
    func read() -> EffectDelayDisplayValue {
        reads += 1
        return .init(slot)
    }
    _ = withObservationTracking {
        cache.value(active: false, read: read)
    } onChange: {
        changes.changed()
    }
    for step in 0..<1000 {
        slot.publish(.init(kind: 0, x: Double(step) / 1000, y: 0.8, enabled: true, locked: false, delaySync: false))
    }
    #expect(changes.value == 0 && reads == 0)
    let shown = cache.value(active: true, read: read)
    #expect(reads == 1 && shown.delaySync == false && shown.milliseconds == slot.delayMilliseconds)
    cache.freeze(shown)
    slot.publish(.init())
    #expect(cache.value(active: false, read: read) == shown && reads == 1)
}

@Test @MainActor func delaySyncToggleReadsCurrentParametersAndSurvivesPersistence() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(model.toggleEffectDelaySync(slot: 0, deck: .a))
    #expect(model.effectDisplay[.a, 0].delaySync == false)
    model.setEffect(.init(kind: 0, x: 0.2, y: 0.3, enabled: true, locked: true), slot: 0, deck: .a)
    model.setHardwareEffectX(0.8, deck: .a)
    #expect(model.toggleEffectDelaySync(slot: 0, deck: .a))
    #expect(model.effectDisplay[.a, 0].x == 0.8 && model.effectDisplay[.a, 0].delaySync == false)
    #expect(model.effectDisplay[.a, 0].enabled && model.effectDisplay[.a, 0].locked)
    await model.flushPerformanceWrites()
    let restarted = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(restarted.effectDisplay[.a, 0].delaySync == false)
    #expect(restarted.effectDisplay[.a, 0].x == 0.8 && !restarted.effectDisplay[.a, 0].enabled)
    model.setEffect(.init(kind: 1, x: 0.6, y: 0.7, enabled: true, locked: false), slot: 0, deck: .a)
    #expect(!model.toggleEffectDelaySync(slot: 0, deck: .a))
    #expect(model.effectDisplay[.a, 0].kind == 1 && model.effectDisplay[.a, 0].x == 0.6)
    await model.finishForShutdown()
    await restarted.finishForShutdown()
}

@Test @MainActor func runtimeModelFXForwardsBothDelayModesWithActiveHistory() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let samples = (0..<16384).flatMap { i -> [Float] in [Float(i % 97) / 200, -Float(i % 71) / 200] }
    var outputs: [Bool: [UInt32]] = [:]
    for synced in [false, true] {
        let reference = try ReplicaModel(
            root: root.appendingPathComponent("Reference-\(synced)"), playback: PlaybackController(offline: true))
        let model = try ReplicaModel(
            root: root.appendingPathComponent("Model-\(synced)"), playback: PlaybackController(offline: true))
        for item in [reference, model] {
            let asset = try PCMAsset(interleavedStereo: samples, sampleRate: 48000)
            let generation = try item.playback.core.load(asset, deck: .a, grid: nil, synced: false)
            item.playback.core.processControlsWhileIdle()
            try item.playback.core.play(deck: .a, generation: generation)
        }
        model.effects[.a, default: [:]][0] = .init(delaySync: synced)
        try reference.playback.setEffect(0, slot: 0, x: 0, y: 0.8, enabled: true, deck: .a, synced: synced)
        #expect(model.applyRuntimeEffectControl(kind: 0, slot: 0, x: 0, y: 0.8, enabled: true, deck: .a, persist: true))
        var bits: [UInt32] = []
        for _ in 0..<32 {
            let a = reference.playback.core.renderOffline(frames: 256)
            let b = model.playback.core.renderOffline(frames: 256)
            #expect(a.left.map(\.bitPattern) == b.left.map(\.bitPattern))
            #expect(a.right.map(\.bitPattern) == b.right.map(\.bitPattern))
            bits += b.left.map(\.bitPattern)
            reference.refreshPlayback()
            model.refreshPlayback()
        }
        outputs[synced] = bits
        #expect(model.effectDisplay[.a, 0].delaySync == synced)
        await reference.finishForShutdown()
        await model.finishForShutdown()
        #expect(await model.runtimeEffectsMatchSavedState())
    }
    #expect(outputs[false] != outputs[true])
}
