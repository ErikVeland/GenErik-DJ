import Foundation
import TDJCore

struct NIControllerReportStartup {
    let buttonBytes: Int
    let potBytes: Int
    private var requestedPots = false
    private(set) var ready = false

    init(buttonBytes: Int, potBytes: Int) {
        self.buttonBytes = buttonBytes
        self.potBytes = potBytes
    }

    mutating func consume(_ frame: Z1AccessoryProtocol.Frame) throws -> UInt8? {
        switch frame.reportID {
        case 1:
            guard frame.payload.count == buttonBytes else { throw TransportError.invalid }
            if !requestedPots {
                requestedPots = true
                return 2
            }
        case 2:
            guard frame.payload.count == potBytes else { throw TransportError.invalid }
            if requestedPots { ready = true }
        default: break
        }
        return nil
    }
}

enum S2MK3AccessoryProtocol {
    static let identifier = "com.native-instruments.protocol.kontrols2mk3"

    static func startup() -> NIControllerReportStartup { .init(buttonBytes: 19, potBytes: 38) }

    static func feedback(_ report: [UInt8]) throws -> [UInt8] {
        guard report.count == 62, report.first == 0x80 else { throw TransportError.invalid }
        return [0xb3, 0xc3, 0, 62, 0] + report
    }
}

enum S2BrowserCommand: Equatable {
    case move(Int, groups: Bool)
    case openGroup
    case load(DeckID)
    case prepare(top: Bool)
    case sample(Int)
    case previewS3
}

enum S2MixerFX: Int {
    case filter, reverb, delay, flanger, gater

    static let s2Presets: [Self] = [.filter, .reverb, .delay, .flanger]

    var effect: PerformanceEffect? {
        switch self {
        case .filter: nil
        case .reverb: .reverb
        case .delay: .delay
        case .flanger: .flanger
        case .gater: .gater
        }
    }
}

enum NativeTraktorEvent: Equatable {
    case action(ControllerAction, Double)
    case pot(ControllerAction, Double)
    case deleteCue(DeckID, Int)
    case flux(DeckID)
    case reverse(DeckID, Bool)
    case browser(S2BrowserCommand)
    case eject(DeckID)
    case loopRoll(DeckID, Bool)
    case browserView
    case samplePad(Int, shifted: Bool)
    case sampleGain(Double)
    case fx(S2MixerFX, Set<DeckID>)
    case fxToggle(DeckID)
    case move(DeckID, Int, shifted: Bool)
    case loopSize(DeckID, Int, shifted: Bool)
    case browserOpen
    case park(DeckID, atCue: Bool)
    case gridBegin(DeckID, anchor: Bool)
    case gridMove(DeckID, Int)
    case gridEnd(DeckID)
    case mic
    case quantize
    case s3Layer(DeckID)
    case s3BendEnd(DeckID)
    case s3Action(ControllerAction, DeckID, Double)
    case s3Pot(ControllerAction, DeckID, Double)
    case s3Preview(Bool)
    case s3PreviewSeek(Int)
    case s3EXT(shifted: Bool)
    case s3EXTCue
    case s3EXTLevel(Double, trim: Bool)
    case cloneDeck(DeckID)
    case crossfaderAssign(DeckID, CrossfaderAssignment)
    case loopTrim(DeckID, end: Bool, ticks: Int)
}

struct S2MK3Controls {
    typealias Event = NativeTraktorEvent

    private static let buttons: [(ControllerAction, Int, UInt8)] = [
        (.playA, 2, 0x08), (.playB, 5, 0x20),
        (.cueReturnA, 2, 0x04), (.cueReturnB, 5, 0x10),
        (.syncA, 2, 0x01), (.syncB, 5, 0x04),
        (.keylockA, 2, 0x02), (.keylockB, 5, 0x08),
        (.cueA, 4, 0x01), (.cueB, 4, 0x02),
        (.loopA, 7, 0x04), (.loopB, 7, 0x20),
        (.hotcue1A, 2, 0x10), (.hotcue2A, 2, 0x20), (.hotcue3A, 2, 0x40), (.hotcue4A, 2, 0x80),
        (.hotcue5A, 3, 0x01), (.hotcue6A, 3, 0x02), (.hotcue7A, 3, 0x04), (.hotcue8A, 3, 0x08),
        (.hotcue1B, 5, 0x40), (.hotcue2B, 5, 0x80), (.hotcue3B, 6, 0x01), (.hotcue4B, 6, 0x02),
        (.hotcue5B, 6, 0x04), (.hotcue6B, 6, 0x08), (.hotcue7B, 6, 0x10), (.hotcue8B, 6, 0x20),
    ]
    private static let pots: [(ControllerAction, Int)] = [
        (.tempoA, 0x01), (.levelA, 0x03), (.crossfader, 0x05), (.levelB, 0x07), (.tempoB, 0x09),
        (.gainA, 0x0b), (.highA, 0x0d), (.midA, 0x0f), (.lowA, 0x11), (.filterA, 0x13),
        (.cueMix, 0x19), (.gainB, 0x1d), (.highB, 0x1f), (.midB, 0x21), (.lowB, 0x23), (.filterB, 0x25),
    ]
    private var previousButtons: [UInt8]?
    private var previousPots: [UInt8]?
    private(set) var touched: Set<DeckID> = []
    private(set) var rolling: Set<DeckID> = []
    private(set) var reversing: Set<DeckID> = []
    private(set) var samples: Set<DeckID> = []
    private(set) var gridHeld: Set<DeckID> = []
    private(set) var shifts: Set<DeckID> = []

    static func sampleSlot(deck: DeckID, pad: Int) -> Int {
        (deck == .a ? 0 : 4) + (pad / 4) * 8 + pad % 4
    }

    mutating func consume(_ frame: Z1AccessoryProtocol.Frame) -> [Event] {
        let bytes = frame.payload
        if frame.reportID == 2, bytes.count == 38 {
            let previous = previousPots
            previousPots = bytes
            var events: [Event] = Self.pots.compactMap { action, offset in
                let word = Self.word(bytes, offset: offset)
                guard word <= 4095, previous.map({ Self.word($0, offset: offset) != word }) ?? true else {
                    return nil
                }
                return .pot(action, Double(word) / 4095)
            }
            let gain = Self.word(bytes, offset: 0x17)
            if gain <= 4095, previous.map({ Self.word($0, offset: 0x17) != gain }) ?? true {
                events.append(.sampleGain(Double(gain) / 4095))
            }
            return events
        }
        guard frame.reportID == 1, bytes.count == 19 else { return [] }
        let previous = previousButtons
        previousButtons = bytes
        guard let previous else { return [] }

        func pressed(_ offset: Int, _ mask: UInt8) -> Bool {
            bytes[offset - 1] & mask != 0 && previous[offset - 1] & mask == 0
        }
        shifts = []
        if bytes[0] & 0x20 != 0 { shifts.insert(.a) }
        if bytes[3] & 0x80 != 0 { shifts.insert(.b) }
        if pressed(1, 0x40) { samples.remove(.a) }
        if pressed(5, 0x01) { samples.remove(.b) }
        if pressed(1, 0x80) { samples.insert(.a) }
        if pressed(5, 0x02) { samples.insert(.b) }
        var events: [Event] = Self.buttons.compactMap { action, offset, mask in
            guard pressed(offset, mask) else { return nil }
            let shifted = shifts.contains(action.deck)
            if let pad = action.hotcueSlot {
                if samples.contains(action.deck) {
                    return .samplePad(Self.sampleSlot(deck: action.deck, pad: pad), shifted: shifted)
                }
                if shifted { return .deleteCue(action.deck, pad) }
            }
            return .action(action, 1)
        }
        for fx in S2MixerFX.s2Presets where pressed(3, UInt8(0x10 << fx.rawValue)) {
            events.append(.fx(fx, shifts.isEmpty ? [.a, .b] : shifts))
        }
        if pressed(6, 0x80) { events.append(.mic) }
        if pressed(6, 0x40) { events.append(.quantize) }
        if pressed(1, 0x08) || pressed(4, 0x20) { events.append(.browserView) }
        for (index, deck) in [DeckID.a, .b].enumerated() {
            let left = index == 0
            let browseOffset = left ? 8 : 9
            let browseShift = left ? 0 : 4
            let browseDelta = Self.delta(
                Int(bytes[browseOffset] >> browseShift & 15), Int(previous[browseOffset] >> browseShift & 15),
                modulus: 16)
            if browseDelta != 0 { events.append(.browser(.move(browseDelta, groups: shifts.contains(deck)))) }
            if pressed(7, left ? 0x01 : 0x08) {
                events.append(shifts.contains(deck) ? .eject(deck) : .browser(.load(deck)))
            }
            let moveMask: UInt8 = left ? 0x02 : 0x10
            if pressed(7, moveMask), !shifts.contains(deck) {
                rolling.insert(deck)
                events.append(.loopRoll(deck, true))
            } else if rolling.contains(deck) && bytes[6] & moveMask == 0 {
                rolling.remove(deck)
                events.append(.loopRoll(deck, false))
            }
            if pressed(left ? 1 : 4, left ? 0x04 : 0x10) {
                events.append(.browser(.prepare(top: shifts.contains(deck))))
            }
            let gridMask: UInt8 = left ? 0x10 : 0x40
            let gridOffset = left ? 1 : 4
            if pressed(gridOffset, gridMask), !touched.contains(deck) {
                gridHeld.insert(deck)
                events.append(.gridBegin(deck, anchor: shifts.contains(deck)))
            }
            let wasEditingGrid = gridHeld.contains(deck)
            if wasEditingGrid && bytes[gridOffset - 1] & gridMask == 0 {
                gridHeld.remove(deck)
                events.append(.gridEnd(deck))
            }
            let touchMask: UInt8 = left ? 0x40 : 0x80
            let touch: ControllerAction = left ? .jogTouchA : .jogTouchB
            let wasTouched = touched.contains(deck)
            if pressed(8, touchMask), !wasEditingGrid {
                touched.insert(deck)
                events.append(.action(touch, 1))
            } else if wasTouched && bytes[7] & touchMask == 0 {
                touched.remove(deck)
                events.append(.action(touch, 0))
            }
            if pressed(left ? 1 : 4, left ? 0x02 : 0x08) { events.append(.flux(deck)) }
            let reverseMask: UInt8 = left ? 0x01 : 0x04
            if pressed(left ? 1 : 4, reverseMask) {
                reversing.insert(deck)
                events.append(.reverse(deck, true))
            } else if reversing.contains(deck) && bytes[left ? 0 : 3] & reverseMask == 0 {
                reversing.remove(deck)
                events.append(.reverse(deck, false))
            }
            let loopOffset = left ? 9 : 10
            let shift = left ? 0 : 4
            let loopDelta = Self.delta(
                Int(bytes[loopOffset] >> shift & 15), Int(previous[loopOffset] >> shift & 15), modulus: 16)
            if loopDelta != 0 {
                let action: ControllerAction =
                    left
                    ? (loopDelta > 0 ? .loopUpA : .loopDownA)
                    : (loopDelta > 0 ? .loopUpB : .loopDownB)
                events.append(.action(action, 1))
            }
            let moveOffset = left ? 8 : 10
            let moveShift = left ? 4 : 0
            let moveDelta = Self.delta(
                Int(bytes[moveOffset] >> moveShift & 15), Int(previous[moveOffset] >> moveShift & 15), modulus: 16)
            if moveDelta != 0 {
                let action: ControllerAction =
                    left
                    ? (moveDelta > 0 ? .jumpForwardA : .jumpBackA)
                    : (moveDelta > 0 ? .jumpForwardB : .jumpBackB)
                events.append(.action(action, 1))
            }
            guard !wasTouched || touched.contains(deck) else { continue }
            let offset = left ? 12 : 16
            let wheel = Self.word(bytes, offset: offset) | Self.word(bytes, offset: offset + 2) << 16
            let last = Self.word(previous, offset: offset) | Self.word(previous, offset: offset + 2) << 16
            let ticks = Self.delta(wheel & 1023, last & 1023, modulus: 1024)
            guard ticks != 0 else { continue }
            if wasEditingGrid {
                if gridHeld.contains(deck) { events.append(.gridMove(deck, ticks)) }
                continue
            }
            if touched.contains(deck) {
                let elapsed = ((wheel >> 10) - (last >> 10)) & 0x3fffff
                guard elapsed > 0, elapsed <= 25_000 else { continue }
                let rate = min(4, max(-4, Double(ticks) * 300 / Double(elapsed)))
                events.append(.action(left ? .jogA : .jogB, 0.5 + rate / 8))
            } else if bytes[7] & touchMask == 0 {
                events.append(.action(left ? .wheelJogA : .wheelJogB, min(1, max(0, 0.5 + Double(ticks) / 32))))
            }
        }
        return events
    }

    private static func word(_ bytes: [UInt8], offset: Int) -> Int {
        Int(bytes[offset - 1]) | Int(bytes[offset]) << 8
    }

    private static func delta(_ current: Int, _ previous: Int, modulus: Int) -> Int {
        ((current - previous + modulus / 2) & (modulus - 1)) - modulus / 2
    }
}

struct S2MK3Feedback {
    var sampleDecks: Set<DeckID> = []
    var sampleSlots: Set<Int> = []
    var playingSamples: UInt32 = 0
    var shifts: Set<DeckID> = []
    var gridDecks: Set<DeckID> = []
    var fx: Set<S2MixerFX> = [.filter]
    var browser = false
    var mic = false
    var quantize = true
    var lighting = ControllerPlaybackLights.Options()
}

enum S2MK3Lights {
    static func report(
        snapshot: PlaybackSnapshot, sourceFrames: (a: UInt64?, b: UInt64?),
        cues: (a: Set<Int>, b: Set<Int>), feedback: S2MK3Feedback = .init()
    ) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 62)
        bytes[0] = 0x80
        bytes[0x3c] = feedback.quantize ? 0x7e : 0x7c
        bytes[0x3d] = feedback.mic ? 0x7e : 0x7c
        bytes[0x15] = feedback.playingSamples == 0 ? 0 : 0x7e
        let fxColours: [UInt8] = [0x06, 0x1e, 0x2e, 0x06]
        for fx in S2MixerFX.s2Presets {
            bytes[0x16 + fx.rawValue] = feedback.fx.contains(fx) ? fxColours[fx.rawValue] : 0x7c
        }
        for (index, deck) in [DeckID.a, .b].enumerated() {
            let state = snapshot[deck]
            let base = index == 0 ? 0 : 0x27
            bytes[base + 0x02] = state.fluxEnabled ? 0x7e : 0x7c
            let sampleMode = feedback.sampleDecks.contains(deck)
            bytes[base + 0x04] = feedback.browser ? 0x7e : 0x7c
            bytes[base + 0x05] = feedback.gridDecks.contains(deck) ? 0x7e : 0x7c
            bytes[base + 0x06] = feedback.shifts.contains(deck) ? 0x7e : 0x7c
            bytes[base + 0x07] = sampleMode ? 0x7c : 0x7e
            bytes[base + 0x08] = sampleMode ? 0x7e : 0x7c
            bytes[base + 0x09] = state.synced ? 0x7e : 0x7c
            bytes[base + 0x0a] = state.keylock ? 0x7e : 0x7c
            bytes[base + 0x0c] = state.phase == .playing ? 0x7e : 0x7c
            bytes[0x1a + index] = state.mixer.cue ? 0x7e : 0x7c
            let decibels = 20 * log10(max(1e-12, state.mixer.peak))
            for (segment, threshold) in [-18.0, -12, -6, 0, 6, 9].enumerated() {
                bytes[0x1c + index * 6 + segment] = decibels >= threshold ? 0x7e : 0
            }
            let slots = index == 0 ? cues.a : cues.b
            for slot in 0..<8 {
                let pad = S2MK3Controls.sampleSlot(deck: deck, pad: slot)
                if sampleMode {
                    bytes[base + 0x0d + slot] =
                        feedback.playingSamples & (1 << pad) != 0
                        ? 0x1e : (feedback.sampleSlots.contains(pad) ? 0x26 : 0x7c)
                } else {
                    bytes[base + 0x0d + slot] = slots.contains(slot) ? 0x2e : 0x7c
                }
            }
            if let levels = ControllerPlaybackLights.levels(
                state: state, frameCount: index == 0 ? sourceFrames.a : sourceFrames.b,
                options: feedback.lighting
            ) {
                let amber = palette(levels.amber ?? 0, base: 0x10)
                let blue = palette(levels.amber == nil ? levels.blue : levels.blue * 0.35, base: 0x2c)
                bytes[base + 0x14] = amber ?? blue ?? bytes[base + 0x14]
            }
        }
        return bytes
    }

    private static func palette(_ level: Double, base: UInt8) -> UInt8? {
        guard level > 0.03 else { return nil }
        return base + UInt8(min(2, Int(level * 3)))
    }
}
