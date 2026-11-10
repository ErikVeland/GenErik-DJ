import TDJCore

struct S4MK1Controls {
    private struct Side {
        let shift, select, play, cue, sync, load, loopIn, loopOut, move, size, faster, slower: Int
        let pads, samples: [Int]
    }

    private static let sides = [
        Side(
            shift: 1, select: 8, play: 7, cue: 5, sync: 3, load: 14, loopIn: 10, loopOut: 12,
            move: 19, size: 18, faster: 16, slower: 17, pads: [0, 2, 4, 6], samples: [9, 11, 13, 15]),
        Side(
            shift: 57, select: 48, play: 63, cue: 61, sync: 59, load: 54, loopIn: 50, loopOut: 52,
            move: 43, size: 42, faster: 40, slower: 41, pads: [56, 58, 60, 62], samples: [49, 51, 53, 55]),
    ]
    private static let channels: [(volume: Int, eq: Int, cue: Int, fx: Int)] = [
        (2, 24, 33, 74), (1, 20, 34, 76), (3, 28, 32, 72), (0, 12, 35, 78),
    ]

    private struct Pressure {
        var rest: Int?
        var pressed = false

        mutating func update(_ value: Int) -> Bool? {
            guard let rest, rest > 0 else {
                if value > 0 { self.rest = value }
                return nil
            }
            let previous = pressed
            pressed = value - rest >= (pressed ? 250 : 400)
            if !pressed { self.rest = value < rest ? value : rest + (value - rest) / 16 }
            return pressed == previous ? nil : pressed
        }
    }

    private var pressure = [Pressure(), Pressure()]
    private var previousPanel: [UInt8]?
    private var previousPots: [UInt8]?
    private var cueContacts: Set<DeckID> = []
    private(set) var layers: [DeckID] = [.a, .b]
    private(set) var shifts: Set<DeckID> = []
    private(set) var touched: Set<DeckID> = []
    private(set) var bent: Set<DeckID> = []
    private(set) var tempoLocked: Set<DeckID> = []

    mutating func consume(_ report: [UInt8]) -> [S4MK2Event] {
        switch report.first {
        case 1 where report.count == 32: return panel(report)
        case 2 where report.count == 73: return pots(report)
        default: return []
        }
    }

    private mutating func panel(_ bytes: [UInt8]) -> [S4MK2Event] {
        let previous = previousPanel
        previousPanel = bytes
        let pressureEdges = (0..<2).map { pressure[$0].update(Self.word(bytes, 26 + 2 * $0)) }
        guard let previous else { return [] }
        func down(_ bit: Int) -> Bool { bytes[1 + bit / 8] & (1 << (bit % 8)) != 0 }
        func changed(_ bit: Int) -> Bool {
            (bytes[1 + bit / 8] ^ previous[1 + bit / 8]) & (1 << (bit % 8)) != 0
        }
        func pressed(_ bit: Int) -> Bool { changed(bit) && down(bit) }
        func turn(_ axis: Int) -> Int { Self.delta(Int(bytes[17 + axis]), Int(previous[17 + axis]), wrap: 16) }

        var events: [S4MK2Event] = []
        shifts.removeAll(keepingCapacity: true)
        for (side, config) in Self.sides.enumerated() {
            var deck = layers[side]
            let left = side == 0
            let touch: ControllerAction = left ? .jogTouchA : .jogTouchB
            let changedLayer = pressed(config.select)
            if changedLayer {
                if touched.remove(deck) != nil { events.append(.action(touch, deck, 0)) }
                if bent.remove(deck) != nil { events.append(.bendEnd(deck)) }
                if cueContacts.remove(deck) != nil { events.append(.cue(deck, held: false)) }
                deck = left ? (deck == .a ? .c : .a) : (deck == .b ? .d : .b)
                layers[side] = deck
                events.append(.layer(deck))
            }
            let shifted = down(config.shift)
            if shifted { shifts.insert(deck) }
            guard !changedLayer else { continue }

            if pressed(config.load) {
                events.append(.native(shifted ? .cloneDeck(deck) : .browser(.load(deck))))
            }
            if pressed(config.sync) { events.append(.action(left ? .syncA : .syncB, deck, 1)) }
            if pressed(config.cue) {
                if shifted {
                    events.append(.native(.park(deck, atCue: false)))
                } else {
                    cueContacts.insert(deck)
                    events.append(.cue(deck, held: true))
                }
            }
            if pressed(config.play) {
                if shifted {
                    events.append(.action(left ? .keylockA : .keylockB, deck, 1))
                } else {
                    events.append(
                        cueContacts.contains(deck) ? .cueLatch(deck) : .action(left ? .playA : .playB, deck, 1))
                }
            }
            if !down(config.cue), cueContacts.remove(deck) != nil { events.append(.cue(deck, held: false)) }

            if pressed(config.loopIn) { events.append(.loopMark(deck, end: false)) }
            if pressed(config.loopOut) { events.append(.loopMark(deck, end: true)) }
            if pressed(config.size) { events.append(.loopSet(deck)) }
            if pressed(config.move) { events.append(.loopRecall(deck, stop: false)) }
            if pressed(config.faster) || pressed(config.slower) {
                if tempoLocked.remove(deck) == nil {
                    if down(config.faster) && down(config.slower) {
                        tempoLocked.insert(deck)
                        events.append(.tempoReset(deck))
                    } else if let position = tempoPosition(side: side) {
                        events.append(.tempoPickup(deck, position))
                    }
                }
            }
            let move = turn(1 + side * 2)
            let size = turn(2 + side * 2)
            if move != 0 { events.append(.native(.move(deck, move, shifted: shifted))) }
            if size != 0 { events.append(.native(.loopSize(deck, size, shifted: false))) }

            for (slot, bit) in config.pads.enumerated() where changed(bit) {
                events.append(.pad(deck, slot, held: down(bit), shifted: shifted))
            }
            for (slot, bit) in config.samples.enumerated() where pressed(bit) {
                events.append(.native(.samplePad(Self.sampleSlot(deck: deck, pad: slot), shifted: shifted)))
            }

            if let pressed = pressureEdges[side] {
                if pressed {
                    if bent.remove(deck) != nil { events.append(.bendEnd(deck)) }
                    touched.insert(deck)
                    events.append(.action(touch, deck, 1))
                } else if touched.remove(deck) != nil {
                    events.append(.action(touch, deck, 0))
                }
            }
            let wheel = 13 + side * 2
            let ticks = Self.delta(Self.word(bytes, wheel) & 1023, Self.word(previous, wheel) & 1023, wrap: 1024)
            if ticks != 0 && pressureEdges[side] != false {
                if touched.contains(deck) {
                    let elapsed = (Self.word(bytes, 30) - Self.word(previous, 30)) & 0xffff
                    let rate = min(4, max(-4, Double(ticks) * (shifted ? 17.58 : 1.758) / Double(max(1, elapsed))))
                    events.append(.action(left ? .jogA : .jogB, deck, 0.5 + rate / 8))
                } else if !pressure[side].pressed {
                    bent.insert(deck)
                    events.append(
                        .action(left ? .wheelJogA : .wheelJogB, deck, min(1, max(0, 0.5 + Double(ticks) / 32))))
                }
            }
        }

        if pressed(28) { events.append(.native(.browserView)) }
        if pressed(29) { events.append(.snap) }
        if pressed(31) { events.append(.quantize) }
        if pressed(36) { events.append(.native(.browserOpen)) }
        let browse = turn(0)
        if browse != 0 { events.append(.native(.browser(.move(browse, groups: !shifts.isEmpty)))) }
        for (index, deck) in DeckID.allCases.enumerated() {
            let channel = Self.channels[index]
            if pressed(channel.cue) { events.append(.action(deck.leftSide ? .cueA : .cueB, deck, 1)) }
            for unit in 0..<2 where pressed(channel.fx + unit) {
                events.append(
                    shifts.isEmpty
                        ? .fxAssign(unit, deck) : .native(.crossfaderAssign(deck, unit == 0 ? .left : .right)))
            }
            let gain = turn(5 + index)
            if gain != 0 { events.append(.gain(deck, gain)) }
        }
        for (unit, base) in [65, 89].enumerated() {
            if pressed(base) { events.append(.fxEnable(unit, nil)) }
            for slot in 0..<3 where pressed(base + 1 + slot) { events.append(.fxEnable(unit, slot)) }
        }
        return events
    }

    private mutating func pots(_ bytes: [UInt8]) -> [S4MK2Event] {
        let previous = previousPots
        previousPots = bytes
        guard let previous else { return [] }
        func position(_ axis: Int) -> Double? {
            let offset = 1 + 2 * axis
            let value = Self.word(bytes, offset)
            guard value <= 4095, value != Self.word(previous, offset) else { return nil }
            return min(1, max(0, Double(value - 16) / 4064))
        }

        var events: [S4MK2Event] = []
        for (index, deck) in DeckID.allCases.enumerated() {
            let left = deck.leftSide
            let channel = Self.channels[index]
            let actions: [ControllerAction] =
                left ? [.filterA, .lowA, .midA, .highA] : [.filterB, .lowB, .midB, .highB]
            for (offset, action) in actions.enumerated() {
                if let value = position(channel.eq + offset) { events.append(.pot(action, deck, value)) }
            }
            if let value = position(channel.volume) { events.append(.pot(left ? .levelA : .levelB, deck, value)) }
        }
        for (side, deck) in layers.enumerated() where !shifts.contains(deck) && !tempoLocked.contains(deck) {
            if let value = position(5 + side) { events.append(.pot(side == 0 ? .tempoA : .tempoB, deck, value)) }
        }
        if let value = position(7) { events.append(.pot(.crossfader, .a, value)) }
        if let value = position(9) { events.append(.pot(.cueMix, .a, value)) }
        for (unit, base) in [32, 16].enumerated() {
            for knob in 0..<4 {
                if let value = position(base + knob) { events.append(.fxPot(unit, knob, value)) }
            }
        }
        return events
    }

    static func sampleSlot(deck: DeckID, pad: Int) -> Int { Int(deck.transportIndex) * 4 + pad }

    func tempoPosition(side: Int) -> Double? {
        guard let previousPots else { return nil }
        let value = Self.word(previousPots, 1 + 2 * (5 + side))
        guard value <= 4095 else { return nil }
        return min(1, max(0, Double(value - 16) / 4064))
    }

    mutating func unlockTempo(_ deck: DeckID) { tempoLocked.remove(deck) }

    private static func word(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
    }

    private static func delta(_ current: Int, _ previous: Int, wrap: Int) -> Int {
        ((current - previous + wrap / 2) & (wrap - 1)) - wrap / 2
    }
}
