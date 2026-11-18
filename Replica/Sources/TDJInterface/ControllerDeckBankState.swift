import TDJCore

/**
 * Tracks independent manual A/C and B/D banks with one transition per physical press.
 */
struct ControllerDeckBankState {
    private var selected: [UInt8: DeckID] = [:]
    private var pressed: Set<UInt8> = []

    mutating func receive(_ message: ControllerMIDIMessage, selector: ControllerProfileData.BankChange) -> Bool {
        guard let bank = selector.deckBank, message.group == 0, message.maximum == 127,
            message.kind == .note, message.channel == selector.channel, message.number == selector.number
        else { return false }
        if message.isNoteOff {
            pressed.remove(bank)
            return false
        }
        guard message.value == 127, pressed.insert(bank).inserted else { return false }
        let current = deck(for: bank)
        selected[bank] = selector.decks.first { $0 != current }
        return true
    }

    func deck(for bank: UInt8) -> DeckID {
        selected[bank] ?? (bank == 0 ? .a : .b)
    }
}
