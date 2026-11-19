public enum ControllerPrime4Event: Equatable, Sendable {
    case message(ControllerMIDIMessage)
    case controlsChanged(left: Bool)
}

public struct ControllerPrime4Decoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var decks: [UInt8] = [0, 1]
    private var hotcues = [true, true, true, true]
    private var selectorDown: Set<UInt16> = []
    private var held: [UInt16: (channel: UInt8, number: UInt8, emitted: Bool)] = [:]

    public init() {}

    /**
     * Routes the public PRIME 4 Computer-mode contract while retaining each physical button's release owner.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerPrime4Event] {
        var events: [ControllerPrime4Event] = []
        for message in standard.append(bytes) {
            let channel = message.channel
            let number = message.number
            let key = UInt16(channel) * 128 + UInt16(number)
            if message.kind == .note, channel == 15, (28...31).contains(number) {
                let deck = number - 28
                let side = Int(deck % 2)
                if message.value > 0 {
                    if selectorDown.insert(key).inserted, decks[side] != deck {
                        decks[side] = deck
                        events.append(.controlsChanged(left: side == 0))
                    }
                } else {
                    selectorDown.remove(key)
                }
                continue
            }
            let side: Int
            let logicalNumber: UInt8
            if (4...5).contains(channel) {
                side = Int(channel - 4)
                if message.kind == .control {
                    guard [31, 32, 75].contains(number) else { continue }
                    if number == 32 && message.value != 1 && message.value != 127 { continue }
                    events.append(
                        .message(.init(kind: .control, channel: 4 + decks[side], number: number, value: message.value)))
                    continue
                }
                guard message.kind == .note else { continue }
                if number == 28 {
                    events.append(
                        .message(
                            .init(
                                kind: .note, channel: 14, number: 28, value: message.value, isNoteOff: message.isNoteOff
                            )))
                    continue
                }
                if (11...14).contains(number) {
                    if message.value > 0 {
                        if selectorDown.insert(key).inserted {
                            let enabled = number == 11
                            if hotcues[Int(decks[side])] != enabled {
                                hotcues[Int(decks[side])] = enabled
                                events.append(.controlsChanged(left: side == 0))
                            }
                        }
                    } else {
                        selectorDown.remove(key)
                    }
                    continue
                }
                guard [8, 9, 10, 29, 30, 34, 37, 38].contains(number) || (15...22).contains(number) else { continue }
                logicalNumber = (15...22).contains(number) ? number + 49 : number
            } else if message.kind == .note, channel == 15, number == 1 || number == 2 {
                side = Int(number - 1)
                logicalNumber = 126
            } else {
                continue
            }
            if message.value > 0 {
                guard held[key] == nil else { continue }
                let emits = !(channel < 15 && (15...22).contains(number)) || hotcues[Int(decks[side])]
                let owner = (channel: 4 + decks[side], number: logicalNumber, emitted: emits)
                held[key] = owner
                if emits {
                    events.append(
                        .message(.init(kind: .note, channel: owner.channel, number: owner.number, value: message.value))
                    )
                }
            } else if let owner = held.removeValue(forKey: key), owner.emitted {
                events.append(
                    .message(
                        .init(kind: .note, channel: owner.channel, number: owner.number, value: 0, isNoteOff: true)))
            }
        }
        return events
    }
}
