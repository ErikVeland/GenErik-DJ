import TDJCore

struct S2MK1Controls {
    private static let mixer: [(ControllerAction, DeckID, Int)] = [
        (.levelA, .a, 0x2b), (.levelB, .b, 0x2d), (.crossfader, .a, 0x2f), (.cueMix, .a, 0x31),
        (.tempoA, .a, 0x0f), (.tempoB, .b, 0x1f),
        (.highA, .a, 0x11), (.midA, .a, 0x25), (.lowA, .a, 0x27),
        (.highB, .b, 0x21), (.midB, .b, 0x23), (.lowB, .b, 0x29),
    ]
    private static let faderFields = [(0x2b, 13), (0x2d, 17), (0x2f, 21)]
    private static let knobFields = [
        (0x0b, 0x00), (0x09, 0x06), (0x07, 0x0c), (0x05, 0x12),
        (0x11, 0x18), (0x25, 0x1e), (0x27, 0x24),
        (0x21, 0x2a), (0x23, 0x30), (0x29, 0x36), (0x13, 0x3c),
        (0x1b, 0x42), (0x19, 0x48), (0x17, 0x4e), (0x15, 0x54),
    ]
    private static let defaultPot = NIControllerPotCalibration(minimum: 16, center: nil, maximum: 4080)

    private var lastButtons: [UInt8]?
    private var lastPots: [UInt8]?
    private var knobReports: [UInt8: [UInt8]] = [:]
    private var calibration: [Int: NIControllerPotCalibration] = [:]
    private var pressureThreshold: [DeckID: Int] = [:]
    private var pressedWheels: Set<DeckID> = []
    private var cueHeld: Set<DeckID> = []
    private(set) var shifts: Set<DeckID> = []
    private(set) var samples: Set<DeckID> = []
    private(set) var tempoLocked: Set<DeckID> = []
    private(set) var touched: Set<DeckID> = []
    private(set) var bent: Set<DeckID> = []

    mutating func consume(_ bytes: [UInt8], activeLoop: (DeckID) -> Bool = { _ in false }) -> [S4MK2Event] {
        guard let report = bytes.first else { return [] }
        switch report {
        case 1 where bytes.count == 16: return buttons(bytes, activeLoop: activeLoop)
        case 2 where bytes.count == 52: return pots(bytes, activeLoop: activeLoop)
        case 0xd0...0xd4 where bytes.count == 33:
            addCalibration(bytes)
            return []
        default: return []
        }
    }

    private mutating func buttons(_ bytes: [UInt8], activeLoop: (DeckID) -> Bool) -> [S4MK2Event] {
        let previous = lastButtons
        lastButtons = bytes
        func down(_ offset: Int, _ mask: UInt8) -> Bool { bytes[offset] & mask != 0 }
        shifts = Set(DeckID.primary.filter { down($0.leftSide ? 0x0d : 0x0c, 0x80) })
        guard let previous else { return [] }
        func pressed(_ offset: Int, _ mask: UInt8) -> Bool {
            down(offset, mask) && previous[offset] & mask == 0
        }

        var events: [S4MK2Event] = []
        for (side, deck) in DeckID.primary.enumerated() {
            let left = side == 0
            let transport = left ? 0x0d : 0x0c
            let loop = left ? 0x09 : 0x0b
            let encoderShift = left ? 0 : 4
            let shifted = shifts.contains(deck)
            if pressed(0x0b, left ? 8 : 4) {
                events.append(.native(shifted ? .cloneDeck(deck) : .browser(.load(deck))))
            }
            if pressed(0x0b, left ? 2 : 1), samples.remove(deck) == nil { samples.insert(deck) }
            if pressed(transport, 0x40) { events.append(.action(left ? .syncA : .syncB, deck, 1)) }
            if pressed(transport, 0x20) {
                if shifted {
                    events.append(.native(.park(deck, atCue: false)))
                } else {
                    cueHeld.insert(deck)
                    events.append(.cue(deck, held: true))
                }
            }
            if pressed(transport, 0x10) {
                if shifted {
                    events.append(.action(left ? .keylockA : .keylockB, deck, 1))
                } else {
                    events.append(cueHeld.contains(deck) ? .cueLatch(deck) : .action(left ? .playA : .playB, deck, 1))
                }
            }
            if !down(transport, 0x20), cueHeld.remove(deck) != nil { events.append(.cue(deck, held: false)) }

            if pressed(loop, 0x80) { events.append(shifted ? .quantize : .action(left ? .cueA : .cueB, deck, 1)) }
            let loopActive = activeLoop(deck)
            if !loopActive, pressed(loop, 0x40) { events.append(.loopMark(deck, end: false)) }
            if !loopActive, pressed(loop, 0x20) { events.append(.loopMark(deck, end: true)) }
            if pressed(loop, 0x10), tempoLocked.remove(deck) == nil {
                tempoLocked.insert(deck)
                events.append(.tempoReset(deck))
            }
            if pressed(0x0e, 2 << encoderShift) { events.append(.loopRecall(deck, stop: false)) }
            if pressed(0x0e, 1 << encoderShift) { events.append(shifted ? .filter(deck, nil) : .gain(deck, nil)) }
            if pressed(0x0e, 4 << encoderShift) {
                events.append(.loopSet(deck))
            }
            for slot in 0..<4 {
                let mask: UInt8 = 8 >> slot
                if (bytes[transport] ^ previous[transport]) & mask != 0 {
                    events.append(.pad(deck, slot, held: down(transport, mask), shifted: shifted))
                }
            }
            for unit in 0..<2 where pressed(0x0a, UInt8(2 >> unit) << (side * 2)) {
                events.append(
                    shifted ? .native(.crossfaderAssign(deck, unit == 0 ? .left : .right)) : .fxAssign(unit, deck))
            }

            let wheel = 1 + side * 4
            let ticks = Self.delta(Int(bytes[wheel]), Int(previous[wheel]), modulus: 256)
            let loopEdges = bytes[loop] & 0x60
            if loopActive && loopEdges != 0 {
                if touched.remove(deck) != nil {
                    events.append(.action(left ? .jogTouchA : .jogTouchB, deck, 0))
                }
                if bent.remove(deck) != nil { events.append(.bendEnd(deck)) }
                if ticks != 0 && loopEdges != 0x60 {
                    events.append(.native(.loopTrim(deck, end: loopEdges == 0x20, ticks: ticks)))
                }
            } else if ticks != 0 {
                if touched.contains(deck) {
                    let elapsed = (Self.word(bytes, wheel + 2) - Self.word(previous, wheel + 2)) & 0xffff
                    let rate = min(4, max(-4, Double(ticks) * (shifted ? 17.58 : 1.758) / Double(max(1, elapsed))))
                    events.append(.action(left ? .jogA : .jogB, deck, 0.5 + rate / 8))
                } else if !pressedWheels.contains(deck) {
                    bent.insert(deck)
                    let value = min(1, max(0, 0.5 + Double(ticks) / 32))
                    events.append(.action(left ? .wheelJogA : .wheelJogB, deck, value))
                }
            }
        }

        if shifts.isEmpty, pressed(0x0e, 8) { events.append(.native(.browserView)) }
        for unit in 0..<2 {
            let offset = unit == 0 ? 0x09 : 0x0a
            let base: UInt8 = unit == 0 ? 8 : 0x80
            if pressed(offset, base) { events.append(.fxEnable(unit, nil)) }
            for slot in 0..<3 where pressed(offset, base >> (slot + 1)) {
                events.append(.fxEnable(unit, slot))
            }
        }
        return events
    }

    private mutating func pots(_ bytes: [UInt8], activeLoop: (DeckID) -> Bool) -> [S4MK2Event] {
        let previous = lastPots
        lastPots = bytes
        func pot(_ offset: Int) -> Double? {
            let raw = Self.word(bytes, offset)
            guard raw <= 4095, let previous, raw != Self.word(previous, offset) else { return nil }
            return (calibration[offset] ?? Self.defaultPot).position(raw)
        }
        func encoder(_ offset: Int, _ shift: Int) -> Int {
            guard let previous else { return 0 }
            return Self.delta(Int(bytes[offset] >> shift & 15), Int(previous[offset] >> shift & 15), modulus: 16)
        }

        var events: [S4MK2Event] = []
        for (side, deck) in DeckID.primary.enumerated() {
            let left = side == 0
            let offset = left ? 0x0d : 0x1d
            if let threshold = pressureThreshold[deck] {
                let raw = Self.word(bytes, offset)
                let wasPressed = pressedWheels.contains(deck)
                let pressed = raw > threshold - (wasPressed ? 16 : 0)
                if pressed != wasPressed {
                    let touch: ControllerAction = left ? .jogTouchA : .jogTouchB
                    if pressed {
                        pressedWheels.insert(deck)
                        let trimming = activeLoop(deck) && (lastButtons.map { $0[left ? 9 : 11] & 0x60 != 0 } ?? false)
                        if previous != nil && !trimming {
                            touched.insert(deck)
                            events.append(.action(touch, deck, 1))
                        }
                    } else {
                        pressedWheels.remove(deck)
                        if touched.remove(deck) != nil { events.append(.action(touch, deck, 0)) }
                    }
                }
            }

            let shifted = shifts.contains(deck)
            let gain = encoder(1 + side * 2, 0)
            if gain != 0 { events.append(shifted ? .filter(deck, gain) : .gain(deck, gain)) }
            let move = encoder(1 + side * 2, 4)
            if move != 0 { events.append(.native(.move(deck, move, shifted: shifted))) }
            let size = encoder(2 + side * 2, 0)
            if size != 0 { events.append(.native(.loopSize(deck, size, shifted: false))) }
        }
        for (action, deck, offset) in Self.mixer {
            if (action == .tempoA || action == .tempoB) && tempoLocked.contains(deck) { continue }
            if let value = pot(offset) { events.append(.pot(action, deck, value)) }
        }
        if let value = pot(0x13) { events.append(.native(.sampleGain(value))) }
        let browse = encoder(2, 4)
        if browse != 0 {
            let fast = shifts.isEmpty && (lastButtons.map { $0[0x0e] & 8 != 0 } ?? false)
            events.append(.native(.browser(.move(browse * (fast ? 10 : 1), groups: !shifts.isEmpty))))
        }
        for unit in 0..<2 {
            for knob in 0..<4 {
                if let value = pot(0x0b + unit * 0x10 - knob * 2) { events.append(.fxPot(unit, knob, value)) }
            }
        }
        return events
    }

    private mutating func addCalibration(_ bytes: [UInt8]) {
        switch bytes[0] {
        case 0xd0:
            for (control, offset) in Self.faderFields {
                setCalibration(
                    control, minimum: Self.word(bytes, offset), center: nil, maximum: Self.word(bytes, offset + 2))
            }
        case 0xd4:
            for (side, deck) in DeckID.primary.enumerated() {
                let offset = 1 + side * 4
                let rest = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
                let pressed = Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
                if rest < pressed && pressed <= 4095 { pressureThreshold[deck] = pressed }
            }
        default:
            knobReports[bytes[0]] = Array(bytes.dropFirst())
            guard let first = knobReports[0xd1], let second = knobReports[0xd2], let third = knobReports[0xd3]
            else { return }
            let fields = first + second + third
            for (control, offset) in Self.knobFields {
                setCalibration(
                    control, minimum: Self.word(fields, offset), center: Self.word(fields, offset + 2),
                    maximum: Self.word(fields, offset + 4))
            }
        }
    }

    private mutating func setCalibration(_ control: Int, minimum: Int, center: Int?, maximum: Int) {
        guard minimum < maximum, maximum <= 4095 else { return }
        let midpoint = center.flatMap { minimum < $0 && $0 < maximum ? $0 : nil }
        calibration[control] = .init(minimum: minimum, center: midpoint, maximum: maximum)
    }

    private static func word(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
    }

    private static func delta(_ current: Int, _ previous: Int, modulus: Int) -> Int {
        ((current - previous + modulus / 2) & (modulus - 1)) - modulus / 2
    }
}

struct S2MK1LoopBounds: Equatable {
    var start: Double
    var end: Double

    func trimming(end trimEnd: Bool, by frames: Double, frameCount: Double) -> Self {
        if trimEnd { return .init(start: start, end: min(frameCount, max(start + 1, end + frames))) }
        return .init(start: max(0, min(end - 1, start + frames)), end: end)
    }
}

struct S2MK1LoopTrim {
    let generation: UInt64
    let original: S2MK1LoopBounds
    var target: S2MK1LoopBounds
    var dirty = true
}
