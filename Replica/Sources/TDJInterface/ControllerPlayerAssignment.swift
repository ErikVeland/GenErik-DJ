import TDJCore

enum ControllerPlayerAssignment {
    /**
     * Keeps connected players on their decks before allocating saved and new identities.
     */
    static func allocate(
        sources: [Int32], current: [Int32: DeckID], saved: [Int32: DeckID], available: [DeckID]
    ) -> [Int32: DeckID] {
        var result: [Int32: DeckID] = [:]
        var used: Set<DeckID> = []
        let identities = Set(sources).sorted()
        for choices in [current, saved] {
            for id in identities where result[id] == nil {
                guard let deck = choices[id], available.contains(deck), used.insert(deck).inserted else { continue }
                result[id] = deck
            }
        }
        for id in identities where result[id] == nil {
            guard let deck = available.first(where: { !used.contains($0) }) else { break }
            result[id] = deck
            used.insert(deck)
        }
        return result
    }
}
