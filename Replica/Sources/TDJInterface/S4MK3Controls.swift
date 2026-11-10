import Foundation
import TDJCore

struct S4MK3Controls {
    private var buttons: [UInt8]?
    private var pots: [UInt8]?
    private var wheels: [UInt8]?
    private var cueHeld: Set<DeckID> = []
    private var previewSide: Int?
    private(set) var layers = DeckID.primary
    private(set) var shifts: Set<DeckID> = []
    private(set) var touched: Set<DeckID> = []
    private(set) var bent: Set<DeckID> = []
    private(set) var reversing: Set<DeckID> = []
    private(set) var gridHeld: Set<DeckID> = []
    private(set) var samples: Set<DeckID> = []

    private static let padBits = [5, 4, 7, 6, 3, 2, 1, 0]

    mutating func consume(_ report: [UInt8]) -> [S4MK2Event] {
        switch report.first {
        case 1 where report.count >= 23: return readButtons(Array(report.dropFirst()))
        case 2 where report.count >= 79: return readPots(Array(report.dropFirst()))
        case 3 where report.count >= 44: return readWheels(report)
        default: return []
        }
    }

    private mutating func readButtons(_ bytes: [UInt8]) -> [S4MK2Event] {
        let previous = buttons
        buttons = bytes
        func held(_ address: Int, _ bit: Int) -> Bool { bytes[address] & (1 << bit) != 0 }
        func changed(_ address: Int, _ bit: Int) -> Bool {
            previous.map { (bytes[address] ^ $0[address]) & (1 << bit) != 0 } ?? false
        }
        func press(_ address: Int, _ bit: Int) -> Bool { changed(address, bit) && held(address, bit) }
        func detents(_ address: Int, _ shift: Int) -> Int {
            guard let previous else { return 0 }
            let delta = Int(bytes[address] >> shift & 15) - Int(previous[address] >> shift & 15)
            return ((delta + 8) & 15) - 8
        }
        var events: [S4MK2Event] = []
        shifts.removeAll(keepingCapacity: true)
        for side in 0..<2 {
            let left = side == 0
            let layerAddress = left ? 5 : 14
            let transport = left ? 4 : 12
            let pads = left ? 3 : 13
            let shift = held(layerAddress, 1)
            let touchBit = left ? 4 : 5
            let touchAction: ControllerAction = left ? .jogTouchA : .jogTouchB
            let previousDeck = layers[side]
            if press(layerAddress, 2) { layers[side] = left ? .a : .b }
            if press(layerAddress, 3) { layers[side] = left ? .c : .d }
            let deck = layers[side]
            if deck != previousDeck {
                if touched.remove(previousDeck) != nil { events.append(.action(touchAction, previousDeck, 0)) }
                if bent.remove(previousDeck) != nil { events.append(.bendEnd(previousDeck)) }
                if cueHeld.remove(previousDeck) != nil { events.append(.cue(previousDeck, held: false)) }
                if gridHeld.remove(previousDeck) != nil { events.append(.native(.gridEnd(previousDeck))) }
                if reversing.remove(previousDeck) != nil { events.append(.native(.reverse(previousDeck, false))) }
                events.append(.layer(deck))
                if let pots, let position = Self.pot(pots, left ? 12 : 10) {
                    events.append(.pot(left ? .tempoA : .tempoB, deck, position))
                }
            }
            if shift { shifts.insert(deck) }
            let cueAddress = left ? 4 : 14
            let cueBit = left ? 1 : 5
            if press(cueAddress, cueBit) {
                if shift {
                    events.append(.native(.park(deck, atCue: false)))
                } else {
                    cueHeld.insert(deck)
                    events.append(.cue(deck, held: true))
                }
            }
            if !held(cueAddress, cueBit), cueHeld.remove(deck) != nil { events.append(.cue(deck, held: false)) }
            if press(transport, 0) {
                if shift {
                    events.append(.action(left ? .keylockA : .keylockB, deck, 1))
                } else {
                    events.append(cueHeld.contains(deck) ? .cueLatch(deck) : .action(left ? .playA : .playB, deck, 1))
                }
            }
            if press(layerAddress, left ? 7 : 4) { events.append(.action(left ? .syncA : .syncB, deck, 1)) }
            if press(left ? 1 : 10, 5) { events.append(.native(.flux(deck))) }
            if press(left ? 1 : 10, 4) {
                reversing.insert(deck)
                events.append(.native(.reverse(deck, true)))
            }
            if !held(left ? 1 : 10, 4), reversing.remove(deck) != nil {
                events.append(.native(.reverse(deck, false)))
            }
            if press(transport, 2) { samples.remove(deck) }
            if press(transport, 4) { samples.insert(deck) }

            let gridBit = left ? 6 : 7
            if press(layerAddress, gridBit), !touched.contains(deck) {
                gridHeld.insert(deck)
                events.append(.native(.gridBegin(deck, anchor: shift)))
            }
            if !held(layerAddress, gridBit), gridHeld.remove(deck) != nil { events.append(.native(.gridEnd(deck))) }
            for (slot, bit) in Self.padBits.enumerated() where changed(pads, bit) {
                let down = held(pads, bit)
                if gridHeld.contains(deck) {
                    if down { events.append(.gridDownbeat(deck, slot % 4)) }
                } else if samples.contains(deck) {
                    if down { events.append(.native(.samplePad(Int(deck.transportIndex) * 8 + slot, shifted: shift))) }
                } else {
                    events.append(.pad(deck, slot, held: down, shifted: shift))
                }
            }
            if press(left ? 6 : 15, left ? 2 : 5) { events.append(.sliceMode(deck)) }
            if press(left ? 6 : 15, left ? 5 : 2) {
                events.append(shift ? .loopRecall(deck, stop: false) : .loopSet(deck))
            }
            let move = detents(left ? 19 : 20, left ? 0 : 4)
            let loop = detents(left ? 19 : 21, left ? 4 : 0)
            let browse = detents(left ? 20 : 21, left ? 0 : 4)
            if move != 0 { events.append(.native(.move(deck, move, shifted: shift))) }
            if loop != 0 { events.append(.native(.loopSize(deck, loop, shifted: false))) }
            let previewAddress = left ? 0 : 9
            let previewBit = left ? 5 : 2
            if press(previewAddress, previewBit) {
                previewSide = side
                events.append(.native(.s3Preview(true)))
            }
            if previewSide == side, !held(previewAddress, previewBit) {
                previewSide = nil
                events.append(.native(.s3Preview(false)))
            }
            if browse != 0 {
                let action: NativeTraktorEvent =
                    previewSide == side
                    ? .s3PreviewSeek(browse) : .browser(.move(browse, groups: shift))
                events.append(.native(action))
            }
            if press(left ? 0 : 10, 1) {
                events.append(.native(shift ? .eject(deck) : .browser(.load(deck))))
            }
            if press(left ? 1 : 9, 0) { events.append(.native(.browserView)) }

            if press(16, touchBit), !gridHeld.contains(deck) {
                touched.insert(deck)
                events.append(.action(touchAction, deck, 1))
            }
            if !held(16, touchBit), touched.remove(deck) != nil { events.append(.action(touchAction, deck, 0)) }
        }
        for (index, deck) in DeckID.allCases.enumerated() {
            if press(7, [3, 6, 2, 7][index]) { events.append(.action(deck.leftSide ? .cueA : .cueB, deck, 1)) }
            let firstBits = [3, 5, 0, 7]
            let secondBits = [4, 6, 2, 7]
            if press(2, firstBits[index]) { events.append(.fxAssign(0, deck)) }
            if press(index == 3 ? 11 : 2, secondBits[index]) { events.append(.fxAssign(1, deck)) }
        }
        for unit in 0..<2 {
            let address = unit == 0 ? 1 : 9
            if press(address, unit == 0 ? 6 : 4) { events.append(.fxEnable(unit, nil)) }
            for (slot, bit) in (unit == 0 ? [7, 3, 2] : [5, 6, 7]).enumerated() where press(address, bit) {
                events.append(.fxEnable(unit, slot))
            }
        }
        if press(11, 6) { events.append(.quantize) }
        return events
    }

    private mutating func readPots(_ bytes: [UInt8]) -> [S4MK2Event] {
        let previous = pots
        pots = bytes
        func value(_ offset: Int) -> Double? {
            let value = Self.pot(bytes, offset)
            return previous.flatMap { Self.pot($0, offset) } == value ? nil : value
        }
        var events: [S4MK2Event] = []
        for (index, deck) in DeckID.allCases.enumerated() {
            let left = deck.leftSide
            let eq = [44, 50, 38, 56][index]
            let mapping: [(ControllerAction, Int)] = [
                (left ? .levelA : .levelB, 2 + index * 2),
                (left ? .gainA : .gainB, [16, 18, 14, 20][index]),
                (left ? .highA : .highB, eq), (left ? .midA : .midB, eq + 2),
                (left ? .lowA : .lowB, eq + 4), (left ? .filterA : .filterB, [64, 66, 62, 68][index]),
            ]
            for (action, offset) in mapping {
                if let position = value(offset) { events.append(.pot(action, deck, position)) }
            }
        }
        if let position = value(0) { events.append(.pot(.crossfader, .a, position)) }
        if let position = value(12) { events.append(.pot(.tempoA, layers[0], position)) }
        if let position = value(10) { events.append(.pot(.tempoB, layers[1], position)) }
        for unit in 0..<2 {
            for knob in 0..<4 {
                if let position = value((unit == 0 ? 30 : 70) + knob * 2) {
                    events.append(.fxPot(unit, knob, position))
                }
            }
        }
        return events
    }

    private mutating func readWheels(_ bytes: [UInt8]) -> [S4MK2Event] {
        let previous = wheels
        wheels = bytes
        guard let previous else { return [] }
        let elapsed = Self.dword(bytes, 8) &- Self.dword(previous, 8)
        guard elapsed != 0 else { return [] }
        var events: [S4MK2Event] = []
        for (side, deck) in layers.enumerated() {
            let offset = side == 0 ? 12 : 40
            let ticks = Int(Int32(bitPattern: Self.dword(bytes, offset) &- Self.dword(previous, offset)))
            guard ticks != 0 else { continue }
            if gridHeld.contains(deck) {
                events.append(.native(.gridMove(deck, min(64, max(-64, ticks)))))
            } else {
                let speed = Double(ticks) / Double(elapsed) * 28_790
                if touched.contains(deck) {
                    events.append(.action(side == 0 ? .jogA : .jogB, deck, 0.5 + min(4, max(-4, speed)) / 8))
                } else {
                    bent.insert(deck)
                    events.append(
                        .action(side == 0 ? .wheelJogA : .wheelJogB, deck, 0.5 + min(0.5, max(-0.5, speed / 32))))
                }
            }
        }
        return events
    }

    private static func pot(_ bytes: [UInt8], _ offset: Int) -> Double? {
        let raw = Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
        return raw <= 4095 ? Double(raw) / 4095 : nil
    }

    private static func dword(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
}
