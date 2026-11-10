import Foundation
import TDJCore

enum S4MK2AccessoryProtocol {
    static let identifier = "com.native-instruments.traktordj.kontrols4mk2"
    static let inputBytes = 98

    struct Startup {
        private var expected: UInt8 = 0xd0
        private(set) var ready = false

        mutating func consume(_ frame: Z1AccessoryProtocol.Frame) throws -> UInt8? {
            switch frame.reportID {
            case 0xd0...0xd5:
                guard frame.payload.count == 32 else { throw TransportError.invalid }
                guard frame.reportID == expected else { return nil }
                expected = expected == 0xd5 ? 1 : expected + 1
                return expected
            case 1:
                guard frame.payload.count == S4MK2AccessoryProtocol.inputBytes else { throw TransportError.invalid }
                ready = expected == 1
            default: break
            }
            return nil
        }
    }

    static func feedback(_ report: [UInt8]) throws -> [UInt8] {
        guard report.first == 0x83, report.count == 175 else { throw TransportError.invalid }
        return [0xb3, 0xc3, 0, 175, 0] + report
    }
}

enum S4MK2Event: Equatable {
    case action(ControllerAction, DeckID, Double)
    case pot(ControllerAction, DeckID, Double)
    case micLevel(Double)
    case layer(DeckID)
    case bendEnd(DeckID)
    case native(NativeTraktorEvent)
    case gain(DeckID, Int?)
    case loopMark(DeckID, end: Bool)
    case loopRecall(DeckID, stop: Bool)
    case sliceMode(DeckID)
    case pad(DeckID, Int, held: Bool, shifted: Bool)
    case cue(DeckID, held: Bool)
    case cueLatch(DeckID)
    case masterTempo(Int)
    case gridToggle(DeckID)
    case gridDownbeat(DeckID, Int)
    case loopSet(DeckID)
    case tempoReset(DeckID)
    case record
    case preview
    case quantize
    case snap
    case fxAssign(Int, DeckID)
    case fxEnable(Int, Int?)
    case fxPot(Int, Int, Double)
}

struct S4MK2Controls {
    private struct Calibration {
        let minimum: Int
        let center: Int?
        let maximum: Int

        func position(_ value: Int) -> Double {
            let value = min(maximum, max(minimum, value))
            guard let center else { return Double(value - minimum) / Double(maximum - minimum) }
            return value < center
                ? Double(value - minimum) / Double(center - minimum) * 0.5
                : 0.5 + Double(value - center) / Double(maximum - center) * 0.5
        }
    }

    private static let calibrationOrder = [
        28, 29, 30, 31, 32, 33, 34, 35, 11, 15, 19, 23, 10, 14, 18, 22, 9, 13, 17, 21, 8, 12, 16, 20, 7,
    ]
    private static let linearCalibrationOrder = [24, 25, 26, 27, 1, 2, 0]
    private static let mixer: [(DeckID, Int, Int)] = [
        (.a, 0x37, 0x17), (.b, 0x39, 0x1f), (.c, 0x3b, 0x27), (.d, 0x3d, 0x2f),
    ]

    private var calibrationBytes: [UInt8] = []
    private var calibration: [Int: Calibration] = [:]
    private var previous: [UInt8]?
    private(set) var layers = DeckID.primary
    private var cueHeld: Set<DeckID> = []
    private(set) var touched: Set<DeckID> = []
    private(set) var bent: Set<DeckID> = []
    private(set) var shifts: Set<DeckID> = []
    private(set) var gridEditing: Set<DeckID> = []

    mutating func addCalibration(_ frame: Z1AccessoryProtocol.Frame) {
        guard (0xd0...0xd5).contains(frame.reportID), frame.payload.count == 32,
            Int(frame.reportID - 0xd0) * 32 == calibrationBytes.count
        else { return }
        calibrationBytes.append(contentsOf: frame.payload)
        guard frame.reportID == 0xd5 else { return }

        func valid(_ minimum: Int, _ maximum: Int) -> Bool { minimum < maximum && maximum <= 4095 }
        for (index, pot) in Self.calibrationOrder.enumerated() {
            let offset = 14 + index * 6
            let minimum = Self.word(calibrationBytes, offset)
            let center = Self.word(calibrationBytes, offset + 2)
            let maximum = Self.word(calibrationBytes, offset + 4)
            if valid(minimum, maximum) {
                calibration[pot] = .init(
                    minimum: minimum, center: minimum < center && center < maximum ? center : nil, maximum: maximum)
            }
        }
        for (index, pot) in Self.linearCalibrationOrder.enumerated() {
            let offset = 164 + index * 4
            let minimum = Self.word(calibrationBytes, offset)
            let maximum = Self.word(calibrationBytes, offset + 2)
            if valid(minimum, maximum) { calibration[pot] = .init(minimum: minimum, center: nil, maximum: maximum) }
        }
        calibrationBytes.removeAll()
    }

    mutating func consume(_ bytes: [UInt8]) -> [S4MK2Event] {
        guard bytes.count == S4MK2AccessoryProtocol.inputBytes else { return [] }
        let last = previous
        previous = bytes
        guard last != bytes else { return [] }
        var events: [S4MK2Event] = []

        func held(_ offset: Int, _ mask: UInt8) -> Bool { bytes[offset - 1] & mask != 0 }
        func pressed(_ offset: Int, _ mask: UInt8) -> Bool {
            guard let last else { return false }
            return held(offset, mask) && last[offset - 1] & mask == 0
        }
        func encoder(_ offset: Int, _ shift: Int) -> Int {
            guard let last else { return 0 }
            let index = offset + 19
            return Self.delta(Int(bytes[index] >> shift & 15), Int(last[index] >> shift & 15), modulus: 16)
        }
        func pot(_ offset: Int, force: Bool = false) -> Double? {
            let index = offset + 19
            let value = Self.word(bytes, index)
            guard value <= 4095, force || last.map({ Self.word($0, index) != value }) ?? true else { return nil }
            let range = calibration[(offset - 7) / 2] ?? .init(minimum: 16, center: 2048, maximum: 4080)
            return range.position(value)
        }

        shifts.removeAll(keepingCapacity: true)
        for side in layers.indices {
            let left = side == 0
            let channel = left ? 0x0f : 0x0a
            let transport = left ? 0x0d : 0x0c
            let remix = left ? 0x0e : 0x0b
            let touch: ControllerAction = left ? .jogTouchA : .jogTouchB
            let old = layers[side]
            let switched = pressed(channel, 0x20)
            if switched {
                if cueHeld.remove(old) != nil { events.append(.cue(old, held: false)) }
                if touched.remove(old) != nil { events.append(.action(touch, old, 0)) }
                if bent.remove(old) != nil { events.append(.bendEnd(old)) }
                if gridEditing.remove(old) != nil { events.append(.native(.gridEnd(old))) }
                layers[side] = left ? (old == .a ? .c : .a) : (old == .b ? .d : .b)
                events.append(.layer(layers[side]))
            }
            let deck = layers[side]
            let shifted = held(transport, 0x08)
            if shifted { shifts.insert(deck) }

            if let value = pot(left ? 0x09 : 0x0b, force: switched) {
                events.append(.pot(left ? .tempoA : .tempoB, deck, value))
            }
            if pressed(channel, 0x10) {
                events.append(.native(shifted ? .eject(deck) : .browser(.load(deck))))
            }
            if pressed(transport, 2) {
                if shifted {
                    events.append(.native(.park(deck, atCue: false)))
                } else {
                    cueHeld.insert(deck)
                    events.append(.cue(deck, held: true))
                }
            }
            if pressed(transport, 1) {
                events.append(cueHeld.contains(deck) ? .cueLatch(deck) : .action(left ? .playA : .playB, deck, 1))
            }
            if !held(transport, 2), cueHeld.remove(deck) != nil { events.append(.cue(deck, held: false)) }
            if pressed(transport, 4) {
                if shifted {
                    if gridEditing.remove(deck) != nil {
                        events.append(.native(.gridEnd(deck)))
                    } else {
                        if touched.remove(deck) != nil { events.append(.action(touch, deck, 0)) }
                        if bent.remove(deck) != nil { events.append(.bendEnd(deck)) }
                        gridEditing.insert(deck)
                        events.append(.gridToggle(deck))
                    }
                } else {
                    events.append(.action(left ? .syncA : .syncB, deck, 1))
                }
            }
            let editing = gridEditing.contains(deck)
            if pressed(remix, 1) { events.append(.action(left ? .keylockA : .keylockB, deck, 1)) }
            if pressed(remix, 2) { events.append(.native(.flux(deck))) }
            if pressed(remix, 4) { events.append(.loopMark(deck, end: false)) }
            if pressed(remix, 8) { events.append(.loopMark(deck, end: true)) }
            if pressed(0x13, left ? 0x02 : 0x10) {
                events.append(shifted ? .tempoReset(deck) : .loopSet(deck))
            }
            if pressed(0x13, left ? 0x01 : 0x08) {
                events.append(shifted ? .loopRecall(deck, stop: true) : .sliceMode(deck))
            }
            if let last, !switched {
                for slot in 0..<8 {
                    let offset = slot < 4 ? transport : remix
                    let mask = UInt8(0x80 >> (slot % 4))
                    let down = held(offset, mask)
                    guard down != (last[offset - 1] & mask != 0) else { continue }
                    if editing, slot < 4 {
                        if down { events.append(.gridDownbeat(deck, slot)) }
                    } else {
                        events.append(.pad(deck, slot, held: down, shifted: shifted))
                    }
                }
            }
            let move = encoder(left ? 1 : 2, left ? 0 : 4)
            let size = encoder(left ? 1 : 3, left ? 4 : 0)
            if move != 0 { events.append(.native(.move(deck, move, shifted: shifted))) }
            if size != 0 { events.append(.native(.loopSize(deck, size, shifted: shifted))) }

            let touchMask: UInt8 = left ? 1 : 2
            let release = touched.contains(deck) && !held(0x11, touchMask)
            if release {
                touched.remove(deck)
                events.append(.action(touch, deck, 0))
            } else if pressed(0x11, touchMask), !switched, !editing {
                touched.insert(deck)
                events.append(.action(touch, deck, 1))
            }
            guard let last, !release, !switched else { continue }
            let wheel = Self.wheel(bytes, side * 4)
            let before = Self.wheel(last, side * 4)
            let ticks = Self.delta(wheel & 1023, before & 1023, modulus: 1024)
            guard ticks != 0 else { continue }
            if editing {
                events.append(.native(.gridMove(deck, ticks)))
            } else if touched.contains(deck) {
                let elapsed = ((wheel >> 10) - (before >> 10)) & 0x3fffff
                if (1...25_000).contains(elapsed) {
                    let rate = min(4, max(-4, Double(ticks) * 300 / Double(elapsed)))
                    events.append(.action(left ? .jogA : .jogB, deck, 0.5 + rate / 8))
                }
            } else if !held(0x11, touchMask) {
                bent.insert(deck)
                events.append(.action(left ? .wheelJogA : .wheelJogB, deck, min(1, max(0, 0.5 + Double(ticks) / 32))))
            }
        }

        for (index, (deck, fader, eq)) in Self.mixer.enumerated() {
            let left = deck.leftSide
            let mixerPots: [(ControllerAction, Int)] = [
                (left ? .levelA : .levelB, fader), (left ? .highA : .highB, eq),
                (left ? .midA : .midB, eq + 2), (left ? .lowA : .lowB, eq + 4),
                (left ? .filterA : .filterB, eq + 6),
            ]
            for (action, offset) in mixerPots {
                if let value = pot(offset) { events.append(.pot(action, deck, value)) }
            }
            let outer = index >= 2
            if pressed(left ? 0x0f : 0x0a, outer ? 0x80 : 0x40) {
                events.append(.action(left ? .cueA : .cueB, deck, 1))
            }
            let gain = encoder([3, 4, 4, 5][index], index.isMultiple(of: 2) ? 4 : 0)
            if pressed(0x11, [0x20, 0x40, 0x10, 0x80][index]) {
                events.append(.gain(deck, nil))
            } else if gain != 0 {
                events.append(.gain(deck, gain))
            }
            for unit in 0..<2
            where pressed(left ? 0x12 : 0x10, [[2, 1], [0x80, 0x40], [8, 4], [0x20, 0x10]][index][unit]) {
                events.append(.fxAssign(unit, deck))
            }
        }
        if let value = pot(0x07) { events.append(.pot(.crossfader, .a, value)) }
        if let value = pot(0x0d) { events.append(.pot(.cueMix, .a, value)) }
        // NI's factory PotiMicVol is analog control 4.
        if let value = pot(0x0f) { events.append(.micLevel(value)) }
        let browse = encoder(2, 0)
        if browse != 0 {
            events.append(
                held(0x0f, 2) ? .masterTempo(browse) : .native(.browser(.move(browse, groups: !shifts.isEmpty))))
        }
        if pressed(0x13, 4) { events.append(.native(.browserView)) }
        if pressed(0x0f, 1) { events.append(.preview) }
        if pressed(0x0f, 4) { events.append(.record) }
        if pressed(0x0a, 8) { events.append(.quantize) }
        if pressed(0x0a, 2) { events.append(.snap) }

        for unit in 0..<2 {
            let buttons = unit == 0 ? 0x12 : 0x10
            let mask: UInt8 = unit == 0 ? 0x80 : 8
            if pressed(buttons, mask) { events.append(.fxEnable(unit, nil)) }
            for slot in 0..<3 where pressed(buttons, mask >> (slot + 1)) { events.append(.fxEnable(unit, slot)) }
            for knob in 0..<4 {
                if let value = pot(0x3f + unit * 8 + knob * 2) { events.append(.fxPot(unit, knob, value)) }
            }
        }
        return events
    }

    private static func word(_ bytes: [UInt8], _ index: Int) -> Int {
        Int(bytes[index]) | Int(bytes[index + 1]) << 8
    }

    private static func wheel(_ bytes: [UInt8], _ index: Int) -> Int {
        word(bytes, index) | word(bytes, index + 2) << 16
    }

    private static func delta(_ value: Int, _ previous: Int, modulus: Int) -> Int {
        ((value - previous + modulus / 2) & (modulus - 1)) - modulus / 2
    }
}
