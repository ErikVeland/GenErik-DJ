import TDJCore

extension TraktorFactoryProfile {
    static func factory(_ model: TraktorFactoryModel) -> Self {
        switch model {
        case .x1MK1: x1Original()
        case .x1MK2: x1Second()
        case .f1: remix()
        case .d2, .s5, .s8: screenDecks(model)
        case .z2: z2()
        case .mx2: mx2()
        }
    }

    private static func x1Original() -> Self {
        var p = Self()
        p.bit(1, 36, .surface(0), .shift, .mono(29))
        p.bit(1, 39, .surface(0), .hotcues, .mono(31))
        let transport: [TraktorFactoryControl] = [.play, .cue, .sync, .loopMark(false), .loopMark(true), .jump(-1), .jump(1)]
        let buttons = [[0, 1, 23, 20, 3, 2, 21], [16, 17, 15, 12, 19, 18, 13]]
        let lamps = [[24, 22, 23, 18, 17, 20, 19], [10, 12, 9, 16, 15, 14, 13]]
        let fxPots = [[16, 20, 22, 18], [12, 10, 8, 14]]
        for side in 0..<2 {
            let target = Target.surface(side)
            for i in transport.indices {
                p.bit(1, buttons[side][i], target, transport[i], .mono(lamps[side][i]))
            }
            p.bit(1, 24 + side, target, .load)
            p.bit(1, 26 + side, target, .loop)
            p.bit(1, side == 0 ? 22 : 14, target, .cuePlay, .mono(side == 0 ? 21 : 11))
            p.turn(6, high: side == 1, target, .browse)
            p.turn(7, high: side == 1, target, .loopSize)
            for i in 0..<4 {
                p.bit(1, 28 + 4 * side + i, target, .fxButton(i), .mono(8 - 4 * side - i))
                p.pot(fxPots[side][i], report: 1, bigEndian: true, target, .fxKnob(i))
            }
            for i in 0..<2 {
                let bit = [[9, 8], [38, 37]][side][i]
                p.bit(1, bit, target, .fxAssign(i), .mono(25 + 2 * side + i))
            }
        }
        p.pulses = [.mono(beat: 20, warning: 17), .mono(beat: 14, warning: 15)]
        return p
    }

    private static func x1Second() -> Self {
        var p = Self()
        p.bit(19, 10, .surface(0), .shift, .mono(17))
        p.bit(19, 33, .surface(0), .browser)
        p.turn(17, high: true, .surface(0), .browse)
        let transport: [TraktorFactoryControl] = [.play, .cue, .sync, .flux]
        let transportLED = [[48, 47, 44, 43], [50, 49, 46, 45]]
        let pads = [[19, 22, 31, 34], [25, 28, 37, 40]]
        for side in 0..<2 {
            let target = Target.surface(side)
            p.bit(19, side == 0 ? 11 : 9, target, .load, .mono(side == 0 ? 16 : 18))
            p.bit(19, side == 0 ? 32 : 8, target, .loop)
            p.turn(17 + side, target, .loopSize)
            for i in 0..<4 {
                p.bit(19, (side == 0 ? 24 : 16) + i, target, transport[i], .mono(transportLED[side][i]))
                p.bit(19, (side == 0 ? 31 : 23) - i, target, .pad(i), .rgb(pads[side][i]))
                p.bit(19, 7 - 4 * side - i, target, .fxButton(i), .mono(4 * side + i))
                p.pot(1 + 8 * side + 2 * i, report: 1, target, .fxKnob(i))
            }
            for unit in 0..<2 {
                p.bit(19, 15 - 2 * side - unit, target, .fxAssign(unit), .mono([[8, 9], [14, 15]][side][unit]))
            }
            for finger in 0..<2 {
                p.inputs.append(.init(report: 1, byte: 27 + 2 * finger, encoding: .strip(shared: true), target: target, control: .strip))
            }
        }
        p.pulses = [.paired(blue: 100, amber: 99, count: 10, stride: 2),
                    .paired(blue: 122, amber: 121, count: 10, stride: 2)]
        return p
    }

    private static func remix() -> Self {
        var p = Self()
        let target = Target.surface(0)
        p.button(3, 0x80, target, .shift, .mono(20))
        p.button(3, 0x08, target, .browser, .mono(16))
        p.button(3, 0x04, target, .load)
        p.button(4, 0x04, target, .quantize, .mono(22))
        p.button(4, 0x08, target, .sync, .mono(23))
        p.turn(5, target, .browse)
        for slot in 0..<16 {
            p.button(1 + slot / 8, 0x80 >> (slot % 8), target, .sample(slot), .rgb(24 + 3 * slot))
        }
        for column in 0..<4 {
            p.button(4, 0x80 >> column, target, .stopSampleColumn(column), .mono(78 - 2 * column))
        }
        p.pulses = [.rgb(24 + 3 * 15)]
        return p
    }

    private struct ScreenDeck {
        let transport: [(Int, Int)]
        let pads: [(Int, Int)]
        let fx: [(Int, Int)]
        let strip: Int
        let pulse: (blue: Int, amber: Int)
        let fxPot: Int
    }

    private static func screenDecks(_ model: TraktorFactoryModel) -> Self {
        let deck: [ScreenDeck]
        let controls: [TraktorFactoryControl] =
            [.shift, .play, .cue, .sync, .flux, .hotcues, .freeze, .samples, .layer(nil), .browser, .load, .loop]
        let first = model == .d2 ? 2 : 4
        switch model {
        case .d2:
            deck = [.init(transport: [(55,55), (52,59), (53,58), (54,56), (44,52), (51,44),
                                      (49,48), (48,50), (42,53), (23,37), (3,61), (36,48)],
                          pads: [(43,0), (40,3), (32,6), (33,9), (45,12), (46,15), (47,18), (41,21)],
                          fx: [(7,25), (10,26), (9,27), (8,28)], strip: 13, pulse: (68,93), fxPot: 17)]
        case .s5:
            deck = [.init(transport: [(44,49), (42,53), (45,52), (43,50), (48,48), (54,42),
                                      (49,44), (55,46), (31,38), (24,36), (25,84), (30,85)],
                          pads: [(52,0), (51,3), (53,6), (50,9), (46,12), (41,15), (47,18), (40,21)],
                          fx: [(18,24), (21,25), (19,26), (20,27)], strip: 20, pulse: (54,79), fxPot: 59),
                    .init(transport: [(68,153), (69,157), (66,156), (65,154), (96,152), (104,146),
                                      (111,148), (103,150), (90,142), (89,140), (88,86), (91,87)],
                          pads: [(99,104), (101,107), (97,110), (108,113), (100,116), (98,119), (102,122), (107,125)],
                          fx: [(80,128), (81,129), (82,130), (83,131)], strip: 26, pulse: (158,183), fxPot: 67)]
        default:
            deck = [.init(transport: [(47,55), (44,59), (45,58), (46,56), (36,52), (43,44),
                                      (41,48), (40,50), (34,53), (23,37), (3,53), (28,48)],
                          pads: [(35,0), (32,3), (24,6), (25,9), (37,12), (38,15), (39,18), (33,21)],
                          fx: [(7,25), (10,26), (9,27), (8,28)], strip: 28, pulse: (68,93), fxPot: 43),
                    .init(transport: [(111,173), (108,177), (109,176), (110,174), (100,170), (107,162),
                                      (105,166), (104,168), (98,171), (87,155), (67,117), (92,112)],
                          pads: [(99,118), (96,121), (88,124), (89,127), (101,130), (102,133), (103,136), (97,139)],
                          fx: [(71,143), (74,144), (73,145), (72,146)], strip: 34, pulse: (186,211), fxPot: 51)]
        }
        var p = Self()
        for (side, spec) in deck.enumerated() {
            let target = Target.surface(side)
            for ((bit, led), control) in zip(spec.transport, controls) {
                p.bit(first, bit, target, control, control == .load || control == .loop ? nil : .mono(led))
            }
            for (slot, (bit, led)) in spec.pads.enumerated() {
                p.bit(first, bit, target, .pad(slot), .rgb(led))
            }
            for (slot, (bit, led)) in spec.fx.enumerated() {
                p.bit(first, bit, target, .fxButton(slot), .mono(led))
                p.pot(spec.fxPot + 2 * slot, target, .fxKnob(slot))
            }
            p.turn(1 + side, high: model != .s5, target, .browse)
            p.turn(1 + side, high: model == .s5, target, .loopSize)
            for finger in 0..<2 {
                p.inputs.append(.init(report: 1, byte: spec.strip + 2 * finger, encoding: .strip(shared: false), target: target, control: .strip))
            }
            p.pulses.append(.paired(blue: spec.pulse.blue, amber: spec.pulse.amber, count: 25, stride: 1))
        }
        if model == .d2 {
            p.bit(first, 50, .surface(0), .loopPads, .mono(46))
            for unit in 0..<2 { p.bit(first, 24 + unit, .surface(0), .fxAssign(unit), .mono(118 + unit)) }
            p.bit(first, 16, .surface(0), .grid, .mono(39))
        } else {
            p.addScreenMixer(model)
        }
        if model == .s8 {
            p.bit(first, 42, .surface(0), .loopPads, .mono(46))
            p.bit(first, 106, .surface(1), .loopPads, .mono(164))
            p.bit(first, 16, .surface(0), .grid, .mono(39))
            p.bit(first, 80, .surface(1), .grid, .mono(157))
        }
        return p
    }

    private static let eq: [ControllerAction] = [.gainA, .highA, .midA, .lowA, .filterA]

    private mutating func addScreenMixer(_ model: TraktorFactoryModel) {
        let s5 = model == .s5
        let decks: [DeckID] = [.a, .b, .c, .d]
        let assignBits = s5 ? [[9,14], [72,73], [11,10], [74,75]] : [[149,150], [172,173], [147,148], [174,175]]
        let assignLamps = s5 ? [210,214,208,216] : [282,286,280,288]
        let meters = s5 ? [238,249,227,260] : [247,258,236,269]
        for (channel, deck) in decks.enumerated() {
            let target = Target.channel(deck)
            pot((s5 ? 1 : 33) + 2 * channel, target, .pot(.levelA))
            for (knob, action) in Self.eq.enumerated() {
                pot((s5 ? 19 : 69) + 10 * channel + 2 * knob, target, .pot(action))
            }
            for unit in 0..<2 {
                bit(4, assignBits[channel][unit], target, .fxAssign(unit), .mono(assignLamps[channel] + unit))
            }
            if s5 {
                bit(4, [17,58,13,62][channel], target, .mixerButton(.filterToggleA), .mono([219,220,218,221][channel]))
                bit(4, [16,61,12,60][channel], target, .mixerButton(.cueA), .mono([223,225,222,226][channel]))
            } else {
                inputs.append(.init(report: 1, byte: 0x27, encoding: .switchField(channel, 1),
                                    target: target, control: .mixerSwitch(.filterToggleA)))
                inputs.append(.init(report: 1, byte: 0x28, encoding: .switchField(channel, 1),
                                    target: target, control: .mixerSwitch(.cueA)))
                inputs.append(.init(report: 1, byte: 0x18, encoding: .switchField([4, 0, 6, 2][channel], 3),
                                    target: target, control: .crossfaderAssign))
            }
            self.meters.append((deck, first: meters[channel], count: 11))
        }
        let target = Target.channel(.a)
        turn(3, target, .masterTempo)
        pot(s5 ? 9 : 41, target, .pot(.crossfader))
        if s5 {
            pot(15, target, .pot(.cueMix))
            pot(17, target, .pot(.monitor))
        }
        bit(4, s5 ? 15 : 171, target, .quantize, .mono(s5 ? 213 : 285))
    }

    private static func z2() -> Self {
        var p = Self()
        p.bit(3, 32, .surface(0), .shift, .mono(5))
        p.bit(3, 7, .surface(0), .browser)
        p.bit(3, 4, .surface(0), .quantize, .mono(3))
        p.turn(1, .surface(0), .browse)
        for side in 0..<2 {
            let target = Target.surface(side)
            let channel = Target.channel(side == 0 ? .a : .b)
            p.bit(3, 8 + side, target, .load, .mono(16 + 8 * side))
            p.bit(3, 14 + side, target, .sync, .mono(19 + 8 * side))
            p.bit(3, side == 0 ? 22 : 45, target, .loop)
            p.turn(side == 0 ? 1 : 2, high: side == 0, target, .loopSize)
            p.bit(3, side == 0 ? 25 : 33, target, .layer(side == 0 ? .a : .b), .mono(6 + side))
            p.bit(3, side == 0 ? 24 : 34, target, .layer(side == 0 ? .c : .d), .mono(8 + side))
            p.bit(3, 10 + side, channel, .mixerButton(.cueA), .mono(128 + side))
            p.bit(3, side == 0 ? 30 : 39, channel, .mixerButton(.filterToggleA), .mono(13 + 8 * side))
            p.bit(3, side == 0 ? 17 : 40, target, .fxButton(0), .mono(12 + 8 * side))
            p.pot(13 + 14 * side, target, .fxKnob(0))
            p.pot(15 + 14 * side, target, .fxKnob(1))
            for i in 0..<4 {
                p.bit(3, (side == 0 ? 26 : 35) + i, target, .pad(i), .rgb(28 + 12 * side + 3 * i))
            }
            for i in 0..<2 {
                p.bit(3, (side == 0 ? 18 : 41) + i, channel, .fxAssign(i), .mono(14 + 8 * side + i))
            }
            for (i, action) in eq.enumerated() { p.pot(17 + 14 * side + 2 * i, channel, .pot(action)) }
        }
        for (i, deck) in [DeckID.c, .d, .a, .b].enumerated() {
            p.pot(41 + 2 * i, .channel(deck), .pot(.levelA))
        }
        p.pot(7, .channel(.a), .pot(.cueMix))
        p.pot(49, .channel(.a), .pot(.crossfader))
        p.pulses = [.rgb(37), .rgb(49)]
        p.meters = [(.a, 95, 6), (.b, 103, 6)]
        return p
    }

    private static func mx2() -> Self {
        var p = Self()
        let transport: [TraktorFactoryControl] = [.shift, .play, .cue, .sync, .flux, .reverse, .keylock, .clockMaster, .hotcues, .loopPads, .browser, .preview, .load, .loop]
        let buttons: [[(Int, UInt8, Int?)]] = [
            [(2,0x10,12), (4,0x20,29), (4,0x10,28), (2,0x20,13), (2,1,8), (2,2,9), (2,0x80,15),
             (2,0x40,14), (3,1,16), (3,8,19), (1,0x80,7), (1,0x40,6), (10,4,nil), (10,16,nil)],
            [(6,4,42), (8,8,59), (8,4,58), (6,8,43), (5,0x40,38), (5,0x80,39), (6,0x20,45),
             (6,0x10,44), (6,0x40,46), (7,2,49), (5,0x20,37), (5,0x10,36), (10,32,nil), (10,128,nil)],
        ]
        let padBits = [[28,29,30,31,32,33,34,35], [58,59,60,61,62,63,64,65]]
        for side in 0..<2 {
            let target = Target.surface(side)
            let channel = Target.channel(side == 0 ? .a : .b)
            for ((byte, mask, lamp), control) in zip(buttons[side], transport) {
                p.button(byte, mask, target, control, lamp.map(Lamp.mono))
            }
            p.button(side == 0 ? 1 : 5, side == 0 ? 0x20 : 0x08, target, .prepare,
                     .mono(side == 0 ? 5 : 35))
            for i in 0..<8 { p.bit(0, padBits[side][i], target, .pad(i), .palette(20 + 30 * side + i)) }
            for i in 0..<4 {
                p.bit(0, (side == 0 ? 8 : 38) + i, target, .fxButton(i), .mono(30 * side + i))
                p.pot(1 + 8 * side + 2 * i, target, .fxKnob(i))
            }
            p.button(11, 1 << side, target, .jogTouch)
            p.inputs.append(.init(report: 3, byte: 8 + 8 * side, encoding: .wheel, target: target, control: .jog))
            p.turn(12 + side, high: side == 1, target, .browse)
            p.turn(12 + 2 * side, high: side == 0, target, .move)
            p.turn(13 + side, high: side == 1, target, .loopSize)
            p.pot(49 + 2 * side, target, .tempo)
            p.pot(43 + 2 * side, channel, .pot(.levelA))
            for (i, action) in eq.enumerated() { p.pot(17 + 10 * side + 2 * i, channel, .pot(action)) }
            p.bit(0, side == 0 ? 71 : 75, channel, .mixerButton(.cueA), .mono(63 + 4 * side))
            p.bit(0, side == 0 ? 70 : 74, channel, .mixerButton(.filterToggleA), .mono(62 + 4 * side))
            for unit in 0..<2 {
                p.bit(0, 68 + 4 * side + unit, channel, .fxAssign(unit), .mono(60 + 4 * side + unit))
            }
        }
        p.pot(37, .channel(.a), .pot(.master))
        p.pot(39, .channel(.a), .pot(.cueMix))
        p.pot(41, .channel(.a), .pot(.monitor))
        p.pot(47, .channel(.a), .pot(.crossfader))
        for i in 0..<5 {
            p.bit(0, 76 + i, .channel(.a), .mixerFX(i), .mono(68 + i))
        }
        p.pulses = [.palette(first: 74, count: 6), .palette(first: 80, count: 6)]
        p.meters = [(.a, 87, 8), (.b, 96, 8)]
        return p
    }
}
