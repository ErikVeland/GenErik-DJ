import Foundation
import Observation
import TDJCore
import Testing

@testable import TDJInterface

private final class EffectDisplayChanges: @unchecked Sendable {
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

@Test @MainActor func effectDisplaySweepDoesNotInvalidateSelectorsOtherSlotsOrOtherDeck() {
    let display = EffectControlDisplay()
    let kind = EffectDisplayChanges()
    let other = EffectDisplayChanges()
    let position = EffectDisplayChanges()
    var value = EffectControl(kind: 2, x: 0.2, y: 0.3, enabled: true, locked: false)
    display.publish([.a: [0: value]])
    withObservationTracking {
        _ = display[.a, 0].kind
    } onChange: {
        kind.changed()
    }
    withObservationTracking {
        _ = display[.a, 1].x
        _ = display[.a, 2].enabled
        _ = display[.b, 0].y
    } onChange: {
        other.changed()
    }
    withObservationTracking {
        _ = display[.a, 0].x
    } onChange: {
        position.changed()
    }
    for step in 0..<1000 {
        value.x = Double(step) / 1000
        value.y = 1 - value.x
        display.publish([.a: [0: value]])
    }
    #expect(kind.value == 0 && other.value == 0 && position.value == 1)
    #expect(display[.a, 0].x == 0.999 && display[.a, 0].kind == 2)
    value.kind = 3
    display.publish([.a: [0: value]])
    #expect(kind.value == 1 && other.value == 0)
}

@Test @MainActor func effectMarkerIgnoresKindAndLockChangesAndIdenticalPublications() {
    let display = EffectControlDisplay()
    let marker = EffectDisplayChanges()
    let kind = EffectDisplayChanges()
    withObservationTracking {
        _ = EffectPadDisplayValue(display[.b, 2])
    } onChange: {
        marker.changed()
    }
    withObservationTracking {
        _ = display[.b, 2].kind
    } onChange: {
        kind.changed()
    }
    for _ in 0..<1000 { display.publish([:]) }
    #expect(marker.value == 0 && kind.value == 0)
    var value = EffectControl(kind: 5, x: 0.5, y: 0.5, enabled: false, locked: true)
    display.publish([.b: [2: value]])
    #expect(marker.value == 0 && kind.value == 1)
    value.enabled = true
    display.publish([.b: [2: value]])
    #expect(marker.value == 1)
    display.publish([:])
    #expect(EffectPadDisplayValue(display[.b, 2]) == EffectPadDisplayValue())
    #expect(!display[.b, 2].locked && display[.b, 2].kind == 0)
}

@Test @MainActor func hiddenEffectMarkerDoesNotObserveSweepsAndReopensWithFreshValues() {
    let slot = EffectSlotDisplay()
    let changes = EffectDisplayChanges()
    slot.publish(.init(kind: 2, x: 0.2, y: 0.3, enabled: true, locked: true))
    var cache = MixerPaneDisplayCache(EffectPadDisplayValue(slot))
    var reads = 0
    func read() -> EffectPadDisplayValue {
        reads += 1
        return .init(slot)
    }
    let hidden = withObservationTracking {
        cache.value(active: false, read: read)
    } onChange: {
        changes.changed()
    }
    for step in 0..<1000 { slot.publish(.init(kind: 2, x: Double(step) / 1000, y: 0.7, enabled: false, locked: true)) }
    #expect(reads == 0 && changes.value == 0)
    #expect(hidden == EffectPadDisplayValue(x: 0.2, y: 0.3, enabled: true))
    let shown = cache.value(active: true, read: read)
    #expect(reads == 1 && shown == EffectPadDisplayValue(x: 0.999, y: 0.7, enabled: false))
    cache.freeze(shown)
    slot.publish(.init())
    #expect(cache.value(active: false, read: read) == shown && reads == 1)
}

@Test @MainActor func effectContactMovesKeepTheOwnerWithoutPublishingCoordinates() throws {
    let contact = EffectPadContactState()
    let changes = EffectDisplayChanges()
    let point = SurfacePoint(id: 1, x: 0.2, y: 0.3)
    #expect(contact.handle(.init(phase: .moved, points: [point], ending: []), selectedSlot: 1) == nil)
    let began = try #require(contact.handle(.init(phase: .began, points: [point], ending: []), selectedSlot: 1))
    #expect(began.slot == 1 && began.updateX)
    withObservationTracking {
        _ = contact.activeSlot
    } onChange: {
        changes.changed()
    }
    for step in 0..<1000 {
        let moved = SurfacePoint(id: 1, x: 0.2, y: Double(step) / 1000)
        let update = try #require(contact.handle(.init(phase: .moved, points: [moved], ending: []), selectedSlot: 2))
        #expect(update.slot == 1 && !update.updateX)
    }
    #expect(changes.value == 0 && contact.activeSlot == 1)
    let ended = try #require(contact.handle(.init(phase: .ended, points: [point], ending: [1]), selectedSlot: 2))
    #expect(ended.slot == 1 && changes.value == 1 && contact.activeSlot == nil)
    #expect(contact.cancel() == nil)
    #expect(contact.handle(.init(phase: .began, points: [point], ending: []), selectedSlot: 2)?.updateX == true)
    #expect(contact.cancel() == 2 && contact.activeSlot == nil)
}

@Test @MainActor func effectDisplayFollowsNativeModelUpdatesAndPersistedDisabledRestore() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.setEffect(
        .init(kind: 4, x: 0.3, y: 0.7, enabled: true, locked: true, delaySync: false), slot: 2, deck: .b, persist: true)
    #expect(model.effectDisplay[.b, 2].kind == 4)
    #expect(EffectPadDisplayValue(model.effectDisplay[.b, 2]) == .init(x: 0.3, y: 0.7, enabled: true))
    #expect(model.effectDisplay[.b, 2].locked && !model.effectDisplay[.a, 2].locked)
    model.setHardwareEffectX(0.8, deck: .b)
    #expect(model.effectDisplay[.b, 0].x == 0.8 && model.effectDisplay[.b, 2].x == 0.3)
    await model.flushPerformanceWrites()
    let restarted = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(restarted.effectDisplay[.b, 2].kind == 4)
    #expect(EffectPadDisplayValue(restarted.effectDisplay[.b, 2]) == .init(x: 0.3, y: 0.7, enabled: false))
    #expect(!restarted.effectDisplay[.b, 2].locked)
    #expect(restarted.effectDisplay[.b, 2].delaySync == false)
    await model.finishForShutdown()
    await restarted.finishForShutdown()
}

@Test @MainActor func effectDisplayFollowsDirectDictionaryWritebackAndRemoval() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let original = model.effectDisplay[.a, 1]
    for deck in DeckID.allCases {
        for slot in 0..<3 {
            model.effects[deck, default: [:]][slot] = .init(
                kind: slot + 2, x: 0.2, y: 0.7, enabled: true, locked: true, delaySync: false)
            #expect(model.effectDisplay[deck, slot].kind == slot + 2)
            #expect(model.effectDisplay[deck, slot].delaySync == false)
            #expect(EffectPadDisplayValue(model.effectDisplay[deck, slot]) == .init(x: 0.2, y: 0.7, enabled: true))
        }
    }
    model.effects[.a]?[1]?.x = 0.9
    #expect(original.x == 0.9 && model.effectDisplay[.b, 1].x == 0.2)
    model.effects[.a]?[1] = nil
    #expect(model.effectDisplay[.a, 1] === original)
    #expect(EffectPadDisplayValue(original) == EffectPadDisplayValue())
    #expect(original.kind == 0 && !original.locked && original.delaySync == nil)
    model.effects = [:]
    for deck in DeckID.allCases {
        for slot in 0..<3 {
            #expect(EffectPadDisplayValue(model.effectDisplay[deck, slot]) == EffectPadDisplayValue())
            #expect(model.effectDisplay[deck, slot].kind == 0 && !model.effectDisplay[deck, slot].locked)
        }
    }
    await model.finishForShutdown()
}

@Test @MainActor func effectDisplayKeepsHardwareXLockAndCancellationAcrossSlotChanges() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let contact = EffectPadContactState()
    model.setEffect(.init(kind: 2, x: 0.4, y: 0.5, enabled: true, locked: true), slot: 1, deck: .a)
    model.setEffect(.init(kind: 3, x: 0.6, y: 0.5, enabled: true, locked: true), slot: 2, deck: .b)
    model.selectedEffectSlots[.a] = 1
    func route(_ event: SurfaceEvent) {
        let selected = contact.activeSlot ?? model.selectedEffectSlots[.a, default: 0]
        guard let update = contact.handle(event, selectedSlot: selected) else { return }
        model.effectTouch(event, slot: update.slot, deck: .a, updateX: update.updateX, selectSlot: false)
    }
    let first = SurfacePoint(id: 1, x: 0.2, y: 0.3)
    route(.init(phase: .began, points: [first], ending: []))
    model.setHardwareEffectX(0.8, deck: .a)
    model.selectedEffectSlots[.a] = 0
    let moved = SurfacePoint(id: 1, x: 0.2, y: 0.6)
    route(.init(phase: .moved, points: [moved], ending: []))
    #expect(model.effectDisplay[.a, 1].x == 0.8 && model.effectDisplay[.a, 1].y == 0.4)
    #expect(model.selectedEffectSlots[.a] == 0 && contact.activeSlot == 1)
    route(.init(phase: .ended, points: [moved], ending: [1]))
    #expect(model.effectDisplay[.a, 1].enabled && model.effectDisplay[.a, 1].locked)
    model.selectedEffectSlots[.a] = 1
    route(.init(phase: .began, points: [first], ending: []))
    route(.init(phase: .cancelled, points: [first], ending: [1]))
    #expect(!model.effectDisplay[.a, 1].enabled && model.effectDisplay[.a, 1].locked)
    #expect(contact.activeSlot == nil)
    #expect(model.effectDisplay[.b, 2].enabled && model.effectDisplay[.b, 2].locked)
    #expect(model.effectDisplay[.b, 2].x == 0.6)
    await model.finishForShutdown()
}

@Test @MainActor func effectPadLabelShowsNameAndSelectedGridDivision() {
    let slot = EffectSlotDisplay()
    slot.publish(.init(kind: PerformanceEffect.gater.rawValue, x: 0.75, y: 0.5, enabled: true, locked: false))
    #expect(slot.padLabel == "Gater · 1/4 beat")
    slot.publish(.init(kind: PerformanceEffect.gater.rawValue, x: 0, y: 0.5, enabled: true, locked: false))
    #expect(slot.padLabel == "Gater · 1/32 beat")
    slot.publish(.init(kind: PerformanceEffect.flanger.rawValue, x: 1, y: 0.5, enabled: true, locked: false))
    #expect(slot.padLabel == "Flanger · 16 beats")
    slot.publish(.init(kind: PerformanceEffect.beatmasher.rawValue, x: 1, y: 0.5, enabled: true, locked: false))
    #expect(slot.padLabel == "Beatmasher 2 · 1 beat")
    slot.publish(
        .init(kind: PerformanceEffect.delay.rawValue, x: 0, y: 0.5, enabled: true, locked: false, delaySync: false))
    #expect(slot.padLabel == "Delay · 25 ms")
    slot.publish(.init(kind: PerformanceEffect.reverb.rawValue, x: 0.3, y: 0.5, enabled: true, locked: false))
    #expect(slot.padLabel == "Reverb")
    slot.publish(
        .init(kind: PerformanceEffect.transposeStretch.rawValue, x: 0.75, y: 0.5, enabled: true, locked: false))
    #expect(slot.padLabel == "Transpose Stretch · +6.0 st")
    slot.publish(
        .init(kind: PerformanceEffect.transposeStretch.rawValue, x: 0.25, y: 0.5, enabled: true, locked: false))
    #expect(slot.padLabel == "Transpose Stretch · -30.0 st")
}
