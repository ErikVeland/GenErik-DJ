import TDJCore

struct S4MK1FX {
    var group = true
    var single = 0
    var kinds = [0, 1, 2]
    var singleParameters = [0.5, 0.5, 0.5]
    var defaults: [Int: [Double]] = [:]
    var parameterButtons: Set<Int> = []

    mutating func select(slot: Int?) {
        if group {
            if let slot {
                kinds[slot] = (kinds[slot] + 1) % PerformanceEffect.supportedCount
            } else {
                kinds = [0, 1, 2]
            }
        } else {
            single = slot ?? (single + 1) % PerformanceEffect.supportedCount
            resetSingle()
        }
    }

    mutating func resetSingle() {
        singleParameters = defaults[single] ?? [0.5, 0.5, 0.5]
        parameterButtons.removeAll()
    }

    func effect(slot: Int, unit: Int, enabled: Bool, slots: Set<Int>, knobs: [Double]) -> EffectControl? {
        guard enabled else { return nil }
        if group {
            guard slots.contains(slot) else { return nil }
            return .init(kind: kinds[slot], x: knobs[slot + 1], y: knobs[0], enabled: true)
        }
        guard slot == unit else { return nil }
        let trim = (singleParameters[2] - 0.5) * 0.5
        let offset = (parameterButtons.contains(2) ? 0.25 : 0) - (parameterButtons.contains(1) ? 0.25 : 0)
        let x = max(0, min(1, singleParameters[0] + trim + offset))
        return .init(kind: single, x: x, y: min(1, 2 * singleParameters[1]) * knobs[0], enabled: true)
    }
}
