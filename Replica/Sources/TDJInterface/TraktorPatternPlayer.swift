import TDJCore

struct TraktorPatternUnit {
    var mode = 0
    var enabled = false
    var decks: Set<DeckID> = []
    var ducking = false
    var kit = 0
    var sound = 0
    var page: Int?
    var pitch = 0.5
    var decay = 0.5
    var level = 0.6
    var steps: UInt16 = 0x1111

    mutating func button(_ slot: Int, shifted: Bool) -> Bool {
        if slot == 0 && shifted {
            mode = (mode + 1) % 3
            if mode != 2 { page = nil }
            return true
        }
        guard mode == 2 else { return false }
        switch slot {
        case 0: enabled.toggle()
        case 1, 2:
            if shifted { kit ^= 1 }
            else { sound = (sound + (slot == 1 ? 3 : 1)) % 4 }
        case 3: ducking.toggle()
        default: break
        }
        return true
    }

    mutating func knob(_ slot: Int, value: Double) {
        switch slot {
        case 0: level = value
        case 1: steps = [0x1111, 0x5555, 0x1010, 0x4242, 0x2929, 0xa5a5, 0x8088, 0xffff][min(7, Int(value * 8))]
        case 2: pitch = value
        case 3: decay = value
        default: break
        }
    }

    mutating func selectPage(shifted: Bool) {
        guard mode == 2 else { return }
        if shifted { steps = 0 } else { page = page.map { 1 - $0 } ?? 0 }
    }

    mutating func toggleStep(_ slot: Int) {
        guard let page, (0..<8).contains(slot) else { return }
        steps ^= 1 << (page * 8 + slot)
    }

    var settings: UInt64 {
        guard mode == 2, enabled, !decks.isEmpty else { return 0 }
        let assign = decks.reduce(UInt64(0)) { $0 | (1 << ($1.transportIndex + 16)) }
        func byte(_ value: Double) -> UInt64 { UInt64((min(1, max(0, value)) * 255).rounded()) }
        return UInt64(steps) | assign | (1 << 20) | (ducking ? 1 << 21 : 0) | UInt64(kit * 4 + sound) << 24
            | byte(pitch) << 27 | byte(decay) << 35 | byte(level) << 43
    }
}
