import TDJCore

struct TraktorStemMix {
    let generation: UInt64
    var gain = [Double](repeating: 1, count: 4)
    var filters = [Double](repeating: 0, count: 4)
    var muted = Set<Int>()
    var bypassed = Set<Int>()

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

        func changeStem(_ deck: DeckID, update: (inout TraktorStemMix) -> Void) {
            guard var state = stemMix(deck) else { return }
            update(&state)
            traktorStemMixes[deck] = state
            playback.core.setStemMix(deck, settings: state.packed)
        }
    }
#endif
