public enum ControllerSC5000MEvent: Equatable, Sendable {
    case message(ControllerMIDIMessage)
    case deckChanged
    case padModeChanged
}

public struct ControllerSC5000MDecoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var deck: UInt8 = 0
    private var modes: [UInt8] = [27, 27]
    private var layerDown = false
    private var modeDown: Set<UInt8> = []
    private var heldNotes: [UInt8: UInt8] = [:]
    private var heldPads: [UInt8: (deck: UInt8, number: UInt8)] = [:]

    public init() {}

    /**
     * Routes captured Computer-mode controls without treating motor counters as user transport input.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerSC5000MEvent] {
        var result: [ControllerSC5000MEvent] = []
        for message in standard.append(bytes) {
            guard message.channel == 0 else { continue }
            if message.kind == .control {
                guard message.number == 3 || message.number == 6 else { continue }
                result.append(
                    .message(.init(kind: .control, channel: deck, number: message.number, value: message.value)))
                continue
            }
            guard message.kind == .note else { continue }
            let number = message.number
            let pressed = message.value > 0
            if number == 11 {
                if pressed && !layerDown {
                    deck = 1 - deck
                    result.append(.deckChanged)
                }
                layerDown = pressed
                continue
            }
            if (27...30).contains(number) {
                if pressed {
                    if modeDown.insert(number).inserted, modes[Int(deck)] != number {
                        modes[Int(deck)] = number
                        result.append(.padModeChanged)
                    }
                } else {
                    modeDown.remove(number)
                }
                continue
            }
            if number == 26 {
                result.append(
                    .message(
                        .init(kind: .note, channel: 4, number: 26, value: message.value, isNoteOff: message.isNoteOff)))
                continue
            }
            if (32...39).contains(number) {
                if pressed {
                    guard heldPads[number] == nil else { continue }
                    let mode = modes[Int(deck)]
                    guard mode == 27 || mode == 30 else { continue }
                    let logical = (deck: deck, number: number + (mode == 27 ? 32 : 48))
                    heldPads[number] = logical
                    result.append(
                        .message(
                            .init(kind: .note, channel: logical.deck, number: logical.number, value: message.value)))
                } else if let held = heldPads.removeValue(forKey: number) {
                    result.append(
                        .message(.init(kind: .note, channel: held.deck, number: held.number, value: 0, isNoteOff: true))
                    )
                }
                continue
            }
            guard [1, 2, 3, 4, 5, 6, 8, 9, 10, 18, 20, 22, 24, 25].contains(number) else { continue }
            let owner: UInt8
            if pressed {
                owner = heldNotes[number] ?? deck
                heldNotes[number] = owner
            } else {
                owner = heldNotes.removeValue(forKey: number) ?? deck
            }
            result.append(
                .message(
                    .init(
                        kind: .note, channel: owner, number: number, value: message.value, isNoteOff: message.isNoteOff)
                ))
        }
        return result
    }
}
