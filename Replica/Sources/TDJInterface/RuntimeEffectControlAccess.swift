import Foundation
import TDJCore

extension ReplicaModel {
    /// Diagnostic controls use the same model path as the FX pads.
    @discardableResult package func applyRuntimeEffectControl(
        kind: Int, slot: Int, x: Double, y: Double, enabled: Bool, deck: DeckID, persist: Bool
    ) -> Bool {
        guard (0..<3).contains(slot), (0..<PerformanceEffect.supportedCount).contains(kind), x.isFinite, y.isFinite,
            (0...1).contains(x), (0...1).contains(y)
        else { return false }
        var value = effects[deck]?[slot] ?? .init()
        value.kind = kind
        value.x = x
        value.y = y
        value.enabled = enabled
        guard setEffect(value, slot: slot, deck: deck, persist: persist), let actual = effects[deck]?[slot] else {
            return false
        }
        let display = effectDisplay[deck, slot]
        return actual.kind == kind && actual.x == x && actual.y == y && actual.enabled == enabled
            && actual.locked == value.locked && display.kind == kind && display.x == x && display.y == y
            && display.enabled == enabled && display.locked == value.locked && actual.delaySync == value.delaySync
            && display.delaySync == value.delaySync
    }

    /// Check persistence after shutdown, on a utility task.
    package func runtimeEffectsMatchSavedState() async -> Bool {
        let expected = effects
        let url = store.root.appendingPathComponent("effects.json")
        return await Task.detached(priority: .utility) {
            do {
                let actual = try JSONDecoder().decode([DeckID: [Int: EffectControl]].self, from: Data(contentsOf: url))
                guard Set(actual.keys) == Set(expected.keys) else { return false }
                for (deck, slots) in expected {
                    guard let saved = actual[deck], Set(saved.keys) == Set(slots.keys) else { return false }
                    for (slot, value) in slots {
                        guard let saved = saved[slot], saved.kind == value.kind, saved.x == value.x, saved.y == value.y,
                            saved.enabled == value.enabled, saved.locked == value.locked,
                            saved.delaySync == value.delaySync
                        else { return false }
                    }
                }
                return true
            } catch { return false }
        }.value
    }
}
