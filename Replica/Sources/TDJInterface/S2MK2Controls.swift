import Foundation
import TDJCore

enum S2MK2AccessoryProtocol {
    static let identifier = "com.native-instruments.traktordj.kontrols2mk2"
    static let inputBytes = 66

    static func startup() -> NIControllerCalibrationStartup {
        .init(lastCalibration: 0xd3, inputBytes: inputBytes)
    }

    static func feedback(_ report: [UInt8]) throws -> [UInt8] {
        guard report.first == 0x83, report.count == 70 else { throw TransportError.invalid }
        return [0xb3, 0xc3, 0, 70, 0] + report
    }
}

struct S2MK2Controls {
    private static let centeredPots = Array(9...22) + [4, 5]
    private static let linearPots = [1, 2, 7, 8, 0]
    private static let mixer: [(ControllerAction, DeckID, Int)] = [
        (.crossfader, .a, 0), (.tempoA, .a, 1), (.tempoB, .b, 2), (.cueMix, .a, 3),
        (.levelA, .a, 7), (.levelB, .b, 8),
        (.highA, .a, 17), (.midA, .a, 18), (.lowA, .a, 19),
        (.highB, .b, 20), (.midB, .b, 21), (.lowB, .b, 22),
    ]

    private var calibrationBytes: [UInt8] = []
    private var calibration: [Int: NIControllerPotCalibration] = [:]
    private var previous: [UInt8]?
    private var cueHeld: Set<DeckID> = []
    private(set) var touched: Set<DeckID> = []
    private(set) var bent: Set<DeckID> = []
    private(set) var shifts: Set<DeckID> = []
    private(set) var gridEditing: Set<DeckID> = []
    private(set) var samples: Set<DeckID> = []

    mutating func addCalibration(_ frame: Z1AccessoryProtocol.Frame) {
        guard (0xd0...0xd3).contains(frame.reportID), frame.payload.count == 32,
            Int(frame.reportID - 0xd0) * 32 == calibrationBytes.count
        else { return }
        calibrationBytes.append(contentsOf: frame.payload)
        guard frame.reportID == 0xd3 else { return }
        for (index, pot) in Self.centeredPots.enumerated() {
            let offset = 12 + index * 6
            setCalibration(pot, at: offset, center: Self.word(calibrationBytes, offset + 2), width: 6)
        }
        for (index, pot) in Self.linearPots.enumerated() {
            setCalibration(pot, at: 108 + index * 4, center: nil, width: 4)
        }
        calibrationBytes.removeAll()
    }

    private mutating func setCalibration(_ pot: Int, at offset: Int, center: Int?, width: Int) {
        let minimum = Self.word(calibrationBytes, offset)
        let maximum = Self.word(calibrationBytes, offset + width - 2)
        guard minimum < maximum, maximum <= 4095 else { return }
        let midpoint = center.flatMap { minimum < $0 && $0 < maximum ? $0 : nil }
        calibration[pot] = .init(minimum: minimum, center: midpoint, maximum: maximum)
    }

    mutating func consume(_ bytes: [UInt8]) -> [S4MK2Event] {
        guard bytes.count == S2MK2AccessoryProtocol.inputBytes else { return [] }
        let last = previous
        previous = bytes
        func held(_ address: Int, _ mask: UInt8) -> Bool { bytes[address - 1] & mask != 0 }
        func changed(_ address: Int, _ mask: UInt8) -> Bool {
            guard let last else { return false }
            return (bytes[address - 1] ^ last[address - 1]) & mask != 0
        }
        func pressed(_ address: Int, _ mask: UInt8) -> Bool { held(address, mask) && changed(address, mask) }
        func encoder(_ address: Int, _ shift: Int) -> Int {
            guard let last else { return 0 }
            let index = 15 + address
            return Self.delta(Int(bytes[index] >> shift & 15), Int(last[index] >> shift & 15), modulus: 16)
        }
        func pot(_ index: Int) -> Double? {
            let offset = 20 + index * 2
            let value = Self.word(bytes, offset)
            guard value <= 4095, last.map({ Self.word($0, offset) != value }) ?? true else { return nil }
            return calibration[index]?.position(value) ?? Double(value) / 4095
        }

        shifts = []
        var events: [S4MK2Event] = []
        for (side, deck) in DeckID.primary.enumerated() {
            let left = side == 0
            let transport = left ? 0x0b : 0x09
            let loop = left ? 0x0c : 0x0a
            let shifted = held(transport, 8)
            if shifted { shifts.insert(deck) }
            if pressed(0x0c, left ? 8 : 4) { events.append(.native(shifted ? .eject(deck) : .browser(.load(deck)))) }
            if pressed(0x0c, left ? 2 : 1), samples.remove(deck) == nil { samples.insert(deck) }
            if pressed(transport, 2) {
                if shifted {
                    events.append(.native(.park(deck, atCue: false)))
                } else {
                    cueHeld.insert(deck)
                    events.append(.cue(deck, held: true))
                }
            }
            if pressed(transport, 1) {
                if shifted {
                    events.append(.action(left ? .keylockA : .keylockB, deck, 1))
                } else {
                    events.append(cueHeld.contains(deck) ? .cueLatch(deck) : .action(left ? .playA : .playB, deck, 1))
                }
            }
            if !held(transport, 2), cueHeld.remove(deck) != nil { events.append(.cue(deck, held: false)) }

            let touch: ControllerAction = left ? .jogTouchA : .jogTouchB
            if pressed(transport, 4) {
                if !shifted {
                    events.append(.action(left ? .syncA : .syncB, deck, 1))
                } else if gridEditing.remove(deck) != nil {
                    events.append(.native(.gridEnd(deck)))
                } else {
                    if touched.remove(deck) != nil { events.append(.action(touch, deck, 0)) }
                    if bent.remove(deck) != nil { events.append(.bendEnd(deck)) }
                    gridEditing.insert(deck)
                    events.append(.gridToggle(deck))
                }
            }
            let editing = gridEditing.contains(deck)
            if pressed(loop, 0x10) { events.append(.action(left ? .cueA : .cueB, deck, 1)) }
            if pressed(loop, 0x20) { events.append(.native(.flux(deck))) }
            if pressed(loop, 0x40) { events.append(.loopMark(deck, end: false)) }
            if pressed(loop, 0x80) { events.append(.loopMark(deck, end: true)) }
            if pressed(0x0f, left ? 1 : 8) { events.append(.sliceMode(deck)) }
            if pressed(0x0f, left ? 2 : 0x10) { events.append(.loopSet(deck)) }
            for slot in 0..<4 {
                let mask = UInt8(0x80 >> slot)
                guard changed(transport, mask) else { continue }
                let down = held(transport, mask)
                if editing {
                    if down { events.append(.gridDownbeat(deck, slot)) }
                } else {
                    events.append(.pad(deck, slot, held: down, shifted: shifted))
                }
            }

            let move = encoder(left ? 1 : 2, left ? 0 : 4)
            let size = encoder(left ? 1 : 3, left ? 4 : 0)
            let gain = encoder(left ? 3 : 4, left ? 4 : 0)
            if move != 0 { events.append(.native(.move(deck, move, shifted: shifted))) }
            if size != 0 { events.append(.native(.loopSize(deck, size, shifted: false))) }
            if pressed(0x0d, left ? 0x40 : 0x80) || gain != 0 {
                let detents = gain == 0 ? nil : gain
                events.append(shifted ? .gain(deck, detents) : .filter(deck, detents))
            }
            for unit in 0..<2 where pressed(0x0e, UInt8(8 >> (side * 2 + unit))) {
                events.append(.fxAssign(unit, deck))
            }

            let touchMask: UInt8 = left ? 1 : 2
            let released = !held(0x0a, touchMask) && touched.remove(deck) != nil
            if released { events.append(.action(touch, deck, 0)) }
            if pressed(0x0a, touchMask), !editing {
                touched.insert(deck)
                events.append(.action(touch, deck, 1))
            }
            guard let last, !released else { continue }
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
            } else if !held(0x0a, touchMask) {
                bent.insert(deck)
                events.append(.action(left ? .wheelJogA : .wheelJogB, deck, min(1, max(0, 0.5 + Double(ticks) / 32))))
            }
        }

        for (action, deck, index) in Self.mixer {
            if let value = pot(index) { events.append(.pot(action, deck, value)) }
        }
        if let value = pot(4) { events.append(.native(.sampleGain(value))) }
        let browse = encoder(2, 0)
        if browse != 0 { events.append(.native(.browser(.move(browse, groups: !shifts.isEmpty)))) }
        if pressed(0x0f, 4) { events.append(.native(shifts.isEmpty ? .browserView : .browserOpen)) }
        for unit in 0..<2 {
            let address = unit == 0 ? 0x0e : 0x0d
            if pressed(address, unit == 0 ? 0x10 : 4) { events.append(.fxEnable(unit, nil)) }
            for slot in 0..<3 where pressed(address, UInt8((unit == 0 ? 0x80 : 0x20) >> slot)) {
                events.append(.fxEnable(unit, slot))
            }
            for knob in 0..<4 {
                if let value = pot(9 + unit * 4 + knob) { events.append(.fxPot(unit, knob, value)) }
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
