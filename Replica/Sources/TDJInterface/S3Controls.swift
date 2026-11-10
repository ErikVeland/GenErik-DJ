import Foundation
import TDJCore

enum S3AccessoryProtocol {
    static let identifier = "com.native-instruments.protocol.kontrols3"
    static let buttonBytes = 21
    static let potBytes = 62

    static func startup() -> NIControllerReportStartup { .init(buttonBytes: buttonBytes, potBytes: potBytes) }

    static func feedback(_ report: [UInt8]) throws -> [UInt8] {
        guard
            (report.first == 0x80 && report.count == 83) || (report.first == 0x81 && report.count == 79)
                || (report.first == 0xf4 && report.count == 33)
        else {
            throw TransportError.invalid
        }
        return [0xb3, 0xc3, 0, UInt8(report.count), 0] + report
    }

    static func inputSource(line: Bool) -> [UInt8] {
        [0xf4, 0x20, line ? 0 : 0x08] + Array(repeating: 0, count: 30)
    }
}

struct S3Controls {
    private static let pots: [(ControllerAction, Int)] = [
        (.tempoA, 0x01), (.levelA, 0x05), (.levelB, 0x07), (.crossfader, 0x0b), (.tempoB, 0x0d),
        (.gainA, 0x11), (.gainB, 0x13), (.master, 0x17), (.monitor, 0x1b), (.cueMix, 0x1d),
        (.highA, 0x25), (.midA, 0x27), (.lowA, 0x29), (.highB, 0x2b), (.midB, 0x2d), (.lowB, 0x2f),
        (.filterA, 0x39), (.filterB, 0x3b),
    ]
    private static let outerPots: [(ControllerAction, DeckID, Int)] = [
        (.levelA, .c, 0x03), (.gainA, .c, 0x0f), (.highA, .c, 0x1f), (.midA, .c, 0x21),
        (.lowA, .c, 0x23), (.filterA, .c, 0x37),
        (.highB, .d, 0x31), (.midB, .d, 0x33), (.lowB, .d, 0x35), (.filterB, .d, 0x3d),
    ]
    private static let pads: [[ControllerAction]] = [
        [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A],
        [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B],
    ]
    private static let fxButtons: [(UInt8, S2MixerFX)] = [
        (0x08, .filter), (0x10, .reverb), (0x20, .delay), (0x40, .flanger), (0x80, .filter),
    ]

    private var previousButtons: [UInt8]?
    private var previousPots: [UInt8]?
    private var fxHeld: [(UInt8, S2MixerFX)] = []
    private var fxAssigned = false
    private(set) var browseGroups = false
    private(set) var previewing: DeckID?
    private(set) var shifts: Set<DeckID> = []
    private(set) var samples: Set<DeckID> = []
    private(set) var jogMode = Set(DeckID.allCases)
    private(set) var layers = DeckID.primary
    private(set) var touched: Set<DeckID> = []
    private(set) var bent: Set<DeckID> = []
    private(set) var reversing: Set<DeckID> = []
    private(set) var rolling: Set<DeckID> = []
    private(set) var gridHeld: Set<DeckID> = []

    mutating func consume(_ frame: Z1AccessoryProtocol.Frame) -> [NativeTraktorEvent] {
        let bytes = frame.payload
        if frame.reportID == 2, bytes.count == S3AccessoryProtocol.potBytes {
            let previous = previousPots
            previousPots = bytes
            var events: [NativeTraktorEvent] = Self.pots.compactMap { action, offset in
                let value = Self.word(bytes, offset)
                guard value <= 4095, action != .master || !shifts.isEmpty,
                    previous.map({ Self.word($0, offset) != value }) ?? true
                else { return nil }
                let deck = action == .tempoA ? layers[0] : action == .tempoB ? layers[1] : action.deck
                let position = value == 2047 ? 0.5 : Double(value) / 4095
                return deck == action.deck ? .pot(action, position) : .s3Pot(action, deck, position)
            }
            for (action, deck, offset) in Self.outerPots {
                let value = Self.word(bytes, offset)
                if value <= 4095, previous.map({ Self.word($0, offset) != value }) ?? true {
                    events.append(.s3Pot(action, deck, value == 2047 ? 0.5 : Double(value) / 4095))
                }
            }
            for (offset, trim) in [(0x09, false), (0x15, true)] {
                let value = Self.word(bytes, offset)
                if value <= 4095, previous.map({ Self.word($0, offset) != value }) ?? true {
                    events.append(.s3EXTLevel(value == 2047 ? 0.5 : Double(value) / 4095, trim: trim))
                }
            }
            return events
        }
        guard frame.reportID == 1, bytes.count == S3AccessoryProtocol.buttonBytes else { return [] }
        let previous = previousButtons
        previousButtons = bytes
        guard let previous else { return [] }

        func held(_ offset: Int, _ mask: UInt8) -> Bool { bytes[offset - 1] & mask != 0 }
        func pressed(_ offset: Int, _ mask: UInt8) -> Bool {
            held(offset, mask) && previous[offset - 1] & mask == 0
        }
        func encoder(_ offset: Int, _ shift: Int) -> Int {
            Self.delta(Int(bytes[offset - 1] >> shift & 15), Int(previous[offset - 1] >> shift & 15), modulus: 16)
        }

        var events: [NativeTraktorEvent] = []
        for index in layers.indices {
            let left = index == 0
            let mode = left ? 2 : 5
            let next: DeckID
            if pressed(mode, left ? 0x02 : 0x04) {
                next = left ? .a : .b
            } else if pressed(mode, left ? 0x04 : 0x08) {
                next = left ? .c : .d
            } else { continue }
            let old = layers[index]
            guard old != next else { continue }
            if touched.remove(old) != nil {
                let action: ControllerAction = left ? .jogTouchA : .jogTouchB
                events.append(old == action.deck ? .action(action, 0) : .s3Action(action, old, 0))
            }
            if bent.remove(old) != nil { events.append(.s3BendEnd(old)) }
            if reversing.remove(old) != nil { events.append(.reverse(old, false)) }
            if rolling.remove(old) != nil { events.append(.loopRoll(old, false)) }
            if gridHeld.remove(old) != nil { events.append(.gridEnd(old)) }
            if previewing == old {
                previewing = nil
                events.append(.s3Preview(false))
            }
            layers[index] = next
            events.append(.s3Layer(next))
        }
        shifts = []
        if held(1, 0x01) { shifts.insert(layers[0]) }
        if held(4, 0x02) { shifts.insert(layers[1]) }
        if pressed(7, 0x04) { events.append(.s3EXT(shifted: !shifts.isEmpty)) }
        if pressed(8, 0x04) { events.append(.s3EXTCue) }
        for (mask, choice) in Self.fxButtons where pressed(8, mask) {
            if fxHeld.isEmpty { fxAssigned = false }
            fxHeld.append((mask, choice))
        }
        for (deck, mask) in [(DeckID.a, UInt8(0x10)), (.b, 0x20), (.c, 0x08), (.d, 0x40)]
        where pressed(7, mask) {
            if let choice = fxHeld.last?.1 {
                events.append(.fx(choice, [deck]))
                fxAssigned = true
            } else {
                events.append(.fxToggle(deck))
            }
        }
        let released = fxHeld.last(where: { !held(8, $0.0) })?.1
        fxHeld.removeAll { !held(8, $0.0) }
        if let released, fxHeld.isEmpty, !fxAssigned {
            events.append(.fx(released, Set(DeckID.allCases)))
        }

        for (deck, action, offset, mask) in [
            (DeckID.a, ControllerAction.cueA, 8, UInt8(0x01)), (.b, .cueB, 8, 0x02), (.c, .cueA, 7, 0x80),
        ] where pressed(offset, mask) {
            events.append(deck == action.deck ? .action(action, 1) : .s3Action(action, deck, 1))
        }

        for (index, deck) in layers.enumerated() {
            let left = index == 0
            func mapped(_ action: ControllerAction, _ value: Double) -> NativeTraktorEvent {
                deck == action.deck ? .action(action, value) : .s3Action(action, deck, value)
            }
            let shifted = shifts.contains(deck)
            let top = left ? 1 : 4
            let mode = left ? 2 : 5
            let transport = left ? 3 : 6
            if pressed(mode, left ? 0x20 : 0x40) { samples.remove(deck) }
            if pressed(mode, left ? 0x40 : 0x80) { samples.insert(deck) }
            if pressed(transport, left ? 0x01 : 0x02) {
                events.append(shifted ? .park(deck, atCue: false) : mapped(left ? .playA : .playB, 1))
            }
            if pressed(left ? 2 : 6, left ? 0x80 : 0x01) {
                events.append(shifted ? .park(deck, atCue: true) : mapped(left ? .cueReturnA : .cueReturnB, 1))
            }
            if pressed(mode, left ? 0x08 : 0x10) { events.append(mapped(left ? .syncA : .syncB, 1)) }
            if pressed(mode, left ? 0x10 : 0x20) { events.append(mapped(left ? .keylockA : .keylockB, 1)) }
            if pressed(9, left ? 0x04 : 0x20) { events.append(mapped(left ? .loopA : .loopB, 1)) }

            for (slot, action) in Self.pads[index].enumerated() {
                let bit = slot + (left ? 1 : 2)
                guard pressed(transport + bit / 8, UInt8(1 << (bit % 8))) else { continue }
                if samples.contains(deck) {
                    events.append(.samplePad(S2MK3Controls.sampleSlot(deck: left ? .a : .b, pad: slot), shifted: shifted))
                } else {
                    events.append(shifted ? .deleteCue(deck, slot) : mapped(action, 1))
                }
            }

            if pressed(top, left ? 0x20 : 0x40) {
                browseGroups.toggle()
                events.append(.browserOpen)
            }
            if pressed(top, left ? 0x40 : 0x80) { events.append(.browserView) }
            let previewMask: UInt8 = left ? 0x08 : 0x10
            if pressed(top, previewMask) {
                previewing = deck
                events.append(.s3Preview(true))
            } else if previewing == deck, !held(top, previewMask) {
                previewing = nil
                events.append(.s3Preview(false))
            }
            let browse = encoder(left ? 0x0b : 0x0c, left ? 0 : 4)
            if browse != 0 {
                if previewing == deck {
                    events.append(.s3PreviewSeek(browse))
                } else {
                    events.append(
                        .browser(.move(browse, groups: shifted || browseGroups || held(top, left ? 0x10 : 0x20))))
                }
            }
            if pressed(9, left ? 0x01 : 0x08) {
                events.append(shifted ? .eject(deck) : .browser(.load(deck)))
            }
            let loop = encoder(left ? 0x0c : 0x0d, left ? 0 : 4)
            if loop != 0 { events.append(.loopSize(deck, loop, shifted: shifted)) }
            let move = encoder(left ? 0x0b : 0x0d, left ? 4 : 0)
            if move != 0 { events.append(.move(deck, move, shifted: shifted)) }
            let rollMask: UInt8 = left ? 0x02 : 0x10
            if pressed(9, rollMask), !shifted {
                rolling.insert(deck)
                events.append(.loopRoll(deck, true))
            } else if rolling.contains(deck), !held(9, rollMask) {
                rolling.remove(deck)
                events.append(.loopRoll(deck, false))
            }

            if pressed(top, left ? 0x02 : 0x04) { events.append(.flux(deck)) }
            let reverseMask: UInt8 = left ? 0x04 : 0x08
            if pressed(top, reverseMask) {
                reversing.insert(deck)
                events.append(.reverse(deck, true))
            } else if reversing.contains(deck), !held(top, reverseMask) {
                reversing.remove(deck)
                events.append(.reverse(deck, false))
            }

            let gridOffset = left ? 1 : 5
            let gridMask: UInt8 = left ? 0x80 : 0x01
            let gridPressed = pressed(gridOffset, gridMask)
            let gridWasHeld = gridHeld.contains(deck)
            let touchMask: UInt8 = left ? 0x10 : 0x20
            let touch: ControllerAction = left ? .jogTouchA : .jogTouchB
            if pressed(mode, left ? 0x01 : 0x02) {
                if jogMode.remove(deck) == nil { jogMode.insert(deck) }
            }
            let releaseTouch =
                touched.contains(deck) && (!held(10, touchMask) || !jogMode.contains(deck) || gridPressed)
            if releaseTouch {
                touched.remove(deck)
                events.append(mapped(touch, 0))
            }
            if gridPressed {
                gridHeld.insert(deck)
                events.append(.gridBegin(deck, anchor: shifted))
            } else if gridWasHeld, !held(gridOffset, gridMask) {
                gridHeld.remove(deck)
                events.append(.gridEnd(deck))
            }
            let inGrid = gridHeld.contains(deck)
            if !inGrid, !gridWasHeld, jogMode.contains(deck), pressed(10, touchMask) {
                touched.insert(deck)
                events.append(mapped(touch, 1))
            }
            guard !releaseTouch || inGrid else { continue }
            let offset = left ? 0x0e : 0x12
            let wheel = Self.word(bytes, offset) | Self.word(bytes, offset + 2) << 16
            let last = Self.word(previous, offset) | Self.word(previous, offset + 2) << 16
            let ticks = Self.delta(wheel & 1023, last & 1023, modulus: 1024)
            guard ticks != 0 else { continue }
            if inGrid {
                events.append(.gridMove(deck, ticks))
            } else if !gridWasHeld {
                if touched.contains(deck) {
                    let elapsed = ((wheel >> 10) - (last >> 10)) & 0x3fffff
                    guard elapsed > 0, elapsed <= 25_000 else { continue }
                    let rate = min(4, max(-4, Double(ticks) * 300 / Double(elapsed)))
                    events.append(mapped(left ? .jogA : .jogB, 0.5 + rate / 8))
                } else if !held(10, touchMask) || !jogMode.contains(deck) {
                    bent.insert(deck)
                    events.append(mapped(left ? .wheelJogA : .wheelJogB, min(1, max(0, 0.5 + Double(ticks) / 32))))
                }
            }
        }
        return events
    }

    private static func word(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset - 1]) | Int(bytes[offset]) << 8
    }

    private static func delta(_ current: Int, _ previous: Int, modulus: Int) -> Int {
        ((current - previous + modulus / 2) & (modulus - 1)) - modulus / 2
    }
}

enum S3Lights {
    static func reports(
        snapshot: PlaybackSnapshot, sourceFrames: (a: UInt64?, b: UInt64?), cues: (a: Set<Int>, b: Set<Int>),
        controls: S3Controls = .init(), feedback: S2MK3Feedback = .init(), enabledFX: Set<DeckID> = [.a, .b],
        external: (enabled: Bool, cue: Bool) = (false, false),
        master: (left: Double, right: Double, clipLeft: Bool, clipRight: Bool) = (0, 0, false, false),
        extraFrames: [DeckID: UInt64] = [:], extraCues: [DeckID: Set<Int>] = [:]
    ) -> [[UInt8]] {
        var buttons = [UInt8](repeating: 0, count: 83)
        var meters = [UInt8](repeating: 0, count: 79)
        buttons[0] = 0x80
        meters[0] = 0x81
        buttons[0x33] = external.enabled ? 0xff : 0x04
        buttons[0x3b] = external.enabled && external.cue ? 0xff : 0x04
        for (peak, clipping, start) in [(master.left, master.clipLeft, 0x3d), (master.right, master.clipRight, 0x46)] {
            let db = 20 * log10(max(1e-12, peak))
            for (segment, threshold) in [-36.0, -24, -18, -12, -9, -6, -3, 0].enumerated() {
                meters[start + segment] = db >= threshold ? 0x7f : 0
            }
            meters[start + 8] = clipping ? 0x7e : 0
        }
        let fxPalette: [UInt8] = [0x04, 0x1c, 0x2c, 0x04]
        for fx in S2MixerFX.s2Presets {
            buttons[0x3c + fx.rawValue] = fxPalette[fx.rawValue] + (feedback.fx.contains(fx) ? 3 : 1)
        }
        buttons[0x40] = 0x0c + (feedback.fx.contains(.filter) ? 3 : 1)
        for (index, deck) in controls.layers.enumerated() {
            let state = snapshot[deck]
            let base = index * 0x19
            let playing = state.phase == .playing
            let samples = controls.samples.contains(deck)
            buttons[base + 1] = controls.shifts.contains(deck) ? 0x77 : 0x20
            buttons[base + 2] = white(state.fluxEnabled)
            buttons[base + 3] = controls.reversing.contains(deck) ? 0x77 : 0x20
            buttons[base + 4] = white(controls.previewing == deck)
            buttons[base + 6] = white(controls.browseGroups)
            buttons[base + 7] = white(feedback.browser)
            buttons[base + 8] = white(controls.gridHeld.contains(deck))
            buttons[base + 9] = white(controls.jogMode.contains(deck))
            let primary = deck.transportIndex < 2
            buttons[base + 0x0a] = white(primary)
            buttons[base + 0x0b] = primary ? 0x0d : 0x0f
            buttons[base + 0x0c] = white(state.synced)
            buttons[base + 0x0d] = white(state.keylock)
            buttons[base + 0x0e] = primary ? white(!samples) : samples ? 0x0d : 0x0f
            buttons[base + 0x0f] = primary ? white(samples) : samples ? 0x0f : 0x0d
            buttons[base + 0x10] = white(!playing && state.phase != .empty)
            buttons[base + 0x11] = playing ? 0x77 : 0x20
            let slots = primary ? (deck == .a ? cues.a : cues.b) : extraCues[deck, default: []]
            for slot in 0..<8 {
                let pad = S2MK3Controls.sampleSlot(deck: index == 0 ? .a : .b, pad: slot)
                buttons[base + 0x12 + slot] =
                    samples
                    ? (feedback.playingSamples & (1 << pad) != 0
                        ? 0x1f : (feedback.sampleSlots.contains(pad) ? 0x25 : 0))
                    : (slots.contains(slot) ? 0x2f : 0)
            }
            let levels = ControllerPlaybackLights.levels(
                state: state, frameCount: primary ? (deck == .a ? sourceFrames.a : sourceFrames.b) : extraFrames[deck])
            let amber = palette(levels?.amber ?? 0, base: 0x10)
            let blue = palette((levels?.blue ?? 0) * (levels?.amber == nil ? 1 : 0.35), base: 0x2c)
            let ring = amber ?? blue ?? (playing ? 0x45 : 0)
            for segment in 0..<8 { buttons[0x43 + index * 8 + segment] = ring }
        }
        for (index, deck) in [DeckID.c, .a, .b, .d].enumerated() {
            if deck == .d && external.enabled { continue }
            let state = snapshot[deck]
            buttons[0x34 + index] = white(enabledFX.contains(deck))
            buttons[0x38 + index] = state.mixer.cue ? 0xff : 0x04
            let db = 20 * log10(max(1e-12, state.mixer.peak))
            for (segment, threshold) in [-40.0, -32, -26, -22, -18, -15, -12, -9, -6, -3, 0, 2, 4, 6, 9].enumerated() {
                meters[0x01 + index * 0x0f + segment] = db >= threshold ? 0x7e : 0
            }
        }
        return [buttons, meters]
    }

    private static func white(_ active: Bool) -> UInt8 { active ? 0x47 : 0x45 }

    private static func palette(_ level: Double, base: UInt8) -> UInt8? {
        guard level > 0.03 else { return nil }
        return base + UInt8(min(3, Int(level * 4)))
    }
}
