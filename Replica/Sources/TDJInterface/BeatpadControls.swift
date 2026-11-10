import TDJCore

enum BeatpadEvent: Equatable {
    case shared(S4MK2Event)
    case hotCue(DeckID, Int, delete: Bool)
    case setCue(DeckID)
    case seek(DeckID, Double)
    case brake(DeckID)
    case reverse(DeckID, Bool)
    case bend(DeckID, Int)
    case roll(DeckID, Double, held: Bool)
    case effectSelect(DeckID, Int)
    case effectWet(DeckID, Double)
    case instantFX(DeckID, Int, held: Bool)
    case loadStopped
    case faderStart(DeckID, Double)
}

enum BeatpadIdentity {
    static func matches(_ name: String) -> Bool {
        switch name.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased() {
        case "beatpad", "reloop beatpad", "beatpad 1", "reloop beatpad 1": true
        default: false
        }
    }
}

struct BeatpadControls {
    enum PadMode: Int { case cue, roll, effects, samples }

    struct Side {
        var mode = PadMode.cue
        var scratch = false
        var seek = false
        var cueHeld = false
        var reverse = false
        var bend = 0
        var roll: (note: UInt8, beats: Double)?
        var effect: Int?
        var faderStart = false
        var level: Double?
        var wheelTime: Double?
    }

    private(set) var sides = [Side(), Side()]
    private static let mixer: [(ControllerAction, ControllerAction)] = [
        (.filterA, .filterB), (.fxA, .fxB), (.gainA, .gainB), (.highA, .highB),
        (.midA, .midB), (.lowA, .lowB), (.levelA, .levelB),
    ]

    mutating func consume(_ message: ControllerMIDIMessage, time: Double) -> [BeatpadEvent] {
        guard message.group == 0 else { return [] }
        if message.channel == 4 { return browser(message) }
        guard message.channel < 2 else { return [] }
        let side = Int(message.channel)
        let deck: DeckID = side == 0 ? .a : .b
        switch message.kind {
        case .pitch:
            let offset = message.value - 8192
            let position = 0.5 - Double(offset) / (offset < 0 ? 16_384 : 16_382)
            return [.shared(.pot(side == 0 ? .tempoA : .tempoB, deck, position))]
        case .note:
            return note(message, side: side, deck: deck)
        case .control:
            return control(message, side: side, deck: deck, time: time)
        default:
            return []
        }
    }

    private func browser(_ message: ControllerMIDIMessage) -> [BeatpadEvent] {
        switch (message.kind, message.number) {
        case (.control, 0x42), (.control, 0x02):
            let delta = message.value - 64
            return delta == 0 ? [] : [.shared(.native(.browser(.move(delta, groups: message.number == 2))))]
        case (.control, 0x43), (.control, 0x03): return [.shared(.pot(.cueMix, .a, message.normalized))]
        case (.control, 0x45): return [.shared(.pot(.crossfader, .a, message.normalized))]
        case (.note, 0x46) where message.value > 0: return [.loadStopped]
        case (.note, 0x06) where message.value > 0: return [.shared(.native(.browser(.openGroup)))]
        case (.note, 0x41) where message.value > 0: return [.shared(.record)]
        default: return []
        }
    }

    private mutating func note(_ message: ControllerMIDIMessage, side: Int, deck: DeckID) -> [BeatpadEvent] {
        let raw = message.number
        let held = !message.isNoteOff && message.value > 0
        let shifted = raw < 0x40
        let key = shifted ? raw + 0x40 : raw
        let left = side == 0
        func action(_ a: ControllerAction, _ b: ControllerAction, _ value: Double = 1) -> [BeatpadEvent] {
            [.shared(.action(left ? a : b, deck, value))]
        }

        switch key {
        case 0x63:
            guard sides[side].scratch != held else { return [] }
            sides[side].scratch = held
            sides[side].wheelTime = nil
            return action(.jogTouchA, .jogTouchB, held ? 1 : 0)
        case 0x65:
            sides[side].seek = held
            return []
        case 0x45, 0x46, 0x74:
            if sides[side].scratch {
                sides[side].scratch = false
                return action(.jogTouchA, .jogTouchB, 0)
            }
            return []
        case 0x5f:
            if !held, sides[side].cueHeld {
                sides[side].cueHeld = false
                return [.shared(.cue(deck, held: false))]
            }
            guard held else { return [] }
            if shifted { return [.brake(deck)] }
            guard !sides[side].cueHeld else { return [] }
            sides[side].cueHeld = true
            return [.shared(.cue(deck, held: true))]
        case 0x60:
            if !held, sides[side].reverse {
                sides[side].reverse = false
                return [.reverse(deck, false)]
            }
            guard held else { return [] }
            if shifted {
                sides[side].reverse = true
                return [.reverse(deck, true)]
            }
            return sides[side].cueHeld ? [.shared(.cueLatch(deck))] : action(.playA, .playB)
        case 0x41, 0x42:
            let direction = key == 0x41 ? -1 : 1
            if !held, sides[side].bend == direction {
                sides[side].bend = 0
                return [.bend(deck, 0)]
            }
            guard held else { return [] }
            if shifted { return [.seek(deck, Double(direction))] }
            sides[side].bend = direction
            return [.bend(deck, direction)]
        case 0x50...0x53:
            sides[side].mode = .roll
            if held {
                let beats = [0.125, 0.25, 0.5, 1.0][Int(key - 0x50)] * (shifted ? 16 : 1)
                guard sides[side].roll == nil else { return [] }
                sides[side].roll = (key, beats)
                return [.roll(deck, beats, held: true)]
            }
            guard let roll = sides[side].roll, roll.note == key else { return [] }
            sides[side].roll = nil
            return [.roll(deck, roll.beats, held: false)]
        case 0x54...0x57:
            sides[side].mode = .effects
            let pad = Int(key - 0x54)
            if held {
                if shifted { return [.effectSelect(deck, pad + 1)] }
                sides[side].effect = pad
                return [.instantFX(deck, pad, held: true)]
            }
            guard sides[side].effect == pad else { return [] }
            sides[side].effect = nil
            return [.instantFX(deck, pad, held: false)]
        default:
            break
        }

        guard held else { return [] }
        switch key {
        case 0x43, 0x44: return [.shared(.loopSet(deck))]
        case 0x47: return action(.fxToggleA, .fxToggleB)
        case 0x48...0x4b:
            sides[side].mode = PadMode(rawValue: Int(key - 0x48)) ?? .cue
            return []
        case 0x4c...0x4f:
            sides[side].mode = .cue
            return [.hotCue(deck, Int(key - 0x4c), delete: shifted)]
        case 0x58...0x5b:
            sides[side].mode = .samples
            return [.shared(.native(.samplePad(side * 4 + Int(key - 0x58), shifted: shifted)))]
        case 0x5d:
            return shifted ? [.shared(.native(.park(deck, atCue: false)))] : action(.syncA, .syncB)
        case 0x5e: return shifted ? action(.keylockA, .keylockB) : [.setCue(deck)]
        case 0x61: return action(.cueA, .cueB)
        case 0x62:
            if shifted {
                sides[side].faderStart.toggle()
                return []
            }
            return [.shared(.native(.browser(.load(deck))))]
        case 0x72: return [.effectSelect(deck, 1)]
        case 0x75: return [.shared(.pot(left ? .filterA : .filterB, deck, 0.5))]
        default: return []
        }
    }

    private mutating func control(
        _ message: ControllerMIDIMessage, side: Int, deck: DeckID, time: Double
    ) -> [BeatpadEvent] {
        let raw = message.number
        let key = raw < 0x40 ? raw + 0x40 : raw
        let shifted = raw < 0x40
        let delta = message.value - 64
        let left = side == 0
        switch key {
        case 0x41:
            guard delta != 0 else { return [] }
            return shifted
                ? [.shared(.native(.move(deck, delta, shifted: true)))]
                : [.shared(.native(.loopSize(deck, delta, shifted: false)))]
        case 0x42: return delta == 0 ? [] : [.effectSelect(deck, delta)]
        case 0x43, 0x63:
            guard delta != 0 else { return [] }
            if sides[side].scratch {
                let interval = time - (sides[side].wheelTime ?? time)
                let elapsed = interval > 0 ? min(0.025, max(0.002, interval)) : 0.006
                sides[side].wheelTime = time
                let rate = min(4, max(-4, Double(delta) * 0.00225 / elapsed))
                return [.shared(.action(left ? .jogA : .jogB, deck, 0.5 + rate / 8))]
            }
            return bendWheel(delta, deck: deck, left: left)
        case 0x44, 0x64: return bendWheel(delta, deck: deck, left: left)
        case 0x45, 0x65:
            return delta == 0 ? [] : [.seek(deck, Double(delta) * (sides[side].seek ? 1 : 0.25))]
        case 0x49...0x4f:
            let pair = Self.mixer[Int(key - 0x49)]
            let action = left ? pair.0 : pair.1
            if key == 0x4a && shifted { return [.effectWet(deck, message.normalized)] }
            let value = key == 0x49 && message.value == 64 ? 0.5 : message.normalized
            let event = BeatpadEvent.shared(.pot(action, deck, value))
            if key == 0x4f {
                let previous = sides[side].level
                sides[side].level = value
                if sides[side].faderStart, let previous, (previous == 0) != (value == 0) {
                    return [event, .faderStart(deck, value)]
                }
            }
            return [event]
        default: return []
        }
    }

    private func bendWheel(_ delta: Int, deck: DeckID, left: Bool) -> [BeatpadEvent] {
        guard delta != 0 else { return [] }
        let value = min(1, max(0, 0.5 + Double(delta) / 32))
        return [.shared(.action(left ? .wheelJogA : .wheelJogB, deck, value))]
    }
}
