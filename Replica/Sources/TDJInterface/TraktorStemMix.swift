import TDJCore

struct TraktorStemMix {
    let generation: UInt64
    var gain = [Double](repeating: 1, count: 4)
    var filters = [Double](repeating: 0, count: 4)
    var muted = Set<Int>()
    var bypassed = Set<Int>()
    var sends = [Double](repeating: 1, count: 4)
    var unsent = Set<Int>()

    mutating func toggleMute(_ part: Int) {
        if muted.remove(part) == nil { muted.insert(part) }
    }

    mutating func adjust(_ part: Int, detents: Int, filter: Bool) {
        if filter { filters[part] = min(1, max(-1, filters[part] + Double(detents) / 24)) }
        else { gain[part] = min(1, max(0, gain[part] + Double(detents) / 32)) }
    }

    mutating func toggleSend(_ part: Int) {
        if unsent.remove(part) == nil { unsent.insert(part) }
    }

    var packedSends: UInt32 {
        var result: UInt32 = 0
        for part in 0..<4 where !unsent.contains(part) {
            let level = UInt32((min(1, max(0, sends[part])) * 255).rounded())
            result |= level << (8 * part)
        }
        return result
    }

    var packed: UInt64 {
        var result: UInt64 = 0
        for part in 0..<4 {
            let volume = muted.contains(part) ? 0 : UInt64((min(1, max(0, gain[part])) * 127).rounded())
            let filter = bypassed.contains(part) ? 0 : Int8((min(1, max(-1, filters[part])) * 127).rounded())
            let word = volume | UInt64(UInt8(bitPattern: filter)) << 8
            result |= word << (16 * part)
        }
        return result
    }
}

#if os(iOS)
    extension ReplicaModel {
        func isStemDeck(_ deck: DeckID) -> Bool {
            guard let generation = playback.generations[deck] else { return false }
            return playback.core.asset(generation: generation)?.hasStems == true
        }

        func stemMix(_ deck: DeckID) -> TraktorStemMix? {
            guard let generation = playback.generations[deck], isStemDeck(deck) else { return nil }
            if let current = traktorStemMixes[deck], current.generation == generation { return current }
            return .init(generation: generation)
        }

        func stemPadMutes(_ decks: Set<DeckID>) -> [DeckID: Set<Int>] {
            Dictionary(uniqueKeysWithValues: decks.compactMap { deck in stemMix(deck).map { (deck, $0.muted) } })
        }

        func changeStem(_ deck: DeckID, update: (inout TraktorStemMix) -> Void) {
            guard var state = stemMix(deck) else { return }
            let previous = state
            update(&state)
            traktorStemMixes[deck] = state
            let mix = state.packed
            if mix != previous.packed { playback.core.setStemMix(deck, settings: mix) }
            let sends = state.packedSends
            if sends != previous.packedSends {
                playback.core.setStemSends(deck, generation: state.generation, levels: sends)
            }
        }
    }
#endif
