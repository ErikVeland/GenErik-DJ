import TDJCore

private struct TraktorModularReport {
    let current: [UInt8]
    let previous: [UInt8]?

    func down(_ offset: Int, _ mask: UInt8) -> Bool { current[offset] & mask != 0 }

    func edge(_ offset: Int, _ mask: UInt8) -> Bool? {
        guard let previous, (current[offset] ^ previous[offset]) & mask != 0 else { return nil }
        return down(offset, mask)
    }

    func pressed(_ offset: Int, _ mask: UInt8) -> Bool { edge(offset, mask) == true }

    func pot(_ offset: Int) -> Double? {
        guard let previous, current[offset] != previous[offset] || current[offset + 1] != previous[offset + 1] else {
            return nil
        }
        let raw = Int(current[offset]) | (Int(current[offset + 1]) << 8)
        guard raw <= 4095 else { return nil }
        return raw == 2047 ? 0.5 : Double(raw) / 4095
    }

    func detents(_ offset: Int, side: Int) -> Int {
        guard let previous else { return 0 }
        let shift = side * 4
        let delta = Int(current[offset] >> shift & 0x0f) - Int(previous[offset] >> shift & 0x0f)
        return ((delta + 8) & 0x0f) - 8
    }
}

struct Z1MK2Controls {
    enum Event: Equatable {
        case layer
        case cue(DeckID)
        case pot(ControllerAction, DeckID, Double)
        case fxToggle(DeckID)
        case fxSelect(S2MixerFX)
    }

    private static let knobs: [[ControllerAction]] = [
        [.gainA, .highA, .midA, .lowA, .filterA],
        [.gainB, .highB, .midB, .lowB, .filterB],
    ]
    private static let presets: [(Int, UInt8, S2MixerFX)] = [
        (1, 0x80, .reverb), (2, 0x01, .delay), (2, 0x02, .gater), (2, 0x04, .flanger), (2, 0x08, .filter),
    ]

    private var previous: [UInt8]?
    private(set) var decks: [DeckID] = [.a, .b]
    private(set) var choice: S2MixerFX = .filter

    mutating func disconnect() {
        previous = nil
        decks = [.a, .b]
    }

    mutating func consume(_ bytes: [UInt8]) -> [Event] {
        guard bytes.count == 35, bytes.first == 1 else { return [] }
        let report = TraktorModularReport(current: bytes, previous: previous)
        previous = bytes
        var events: [Event] = []
        let layerChanged = report.pressed(1, 0x04)
        if layerChanged {
            decks = decks[0] == .a ? [.c, .d] : [.a, .b]
            events.append(.layer)
        }
        for (offset, mask, preset) in Self.presets where report.pressed(offset, mask) {
            choice = preset
            events.append(.fxSelect(preset))
        }
        for (side, deck) in decks.enumerated() {
            guard !layerChanged else { continue }
            if report.pressed(2, 0x10 << side) { events.append(.cue(deck)) }
            if report.pressed(1, 0x20 << side) { events.append(.fxToggle(deck)) }
            for (index, action) in Self.knobs[side].enumerated() {
                if let value = report.pot(3 + side * 10 + index * 2) { events.append(.pot(action, deck, value)) }
            }
            if let value = report.pot(29 + side * 2) { events.append(.pot(side == 0 ? .levelA : .levelB, deck, value)) }
        }
        for (offset, action) in [(23, ControllerAction.cueMix), (25, .master), (27, .monitor), (33, .crossfader)] {
            if let value = report.pot(offset) { events.append(.pot(action, .a, value)) }
        }
        return events
    }
}

struct X1MK3Controls {
    enum Event: Equatable {
        case action(ControllerAction, DeckID)
        case cue(DeckID, Bool)
        case reverse(DeckID, Bool)
        case nudge(DeckID, Int, shifted: Bool)
        case hotcue(DeckID, Int, delete: Bool)
        case loopSize(DeckID, Int, shifted: Bool)
        case browse(Int, groups: Bool)
        case load(DeckID)
        case browserView
        case fxAssign(Int, DeckID)
        case fxEnable(Int, Int?)
        case fxPot(Int, Int, Double)
    }

    private static let hotcues: [[(Int, UInt8)]] = [
        [(3, 0x02), (3, 0x04), (2, 0x20), (2, 0x40)],
        [(3, 0x08), (3, 0x10), (2, 0x80), (3, 0x01)],
    ]
    private static let fxButtons: [[(Int, UInt8)]] = [
        [(4, 0x08), (4, 0x02), (3, 0x80), (3, 0x20)],
        [(4, 0x10), (4, 0x04), (4, 0x01), (3, 0x40)],
    ]

    private var previous: [UInt8]?
    private(set) var decks: [DeckID] = [.a, .b]
    private(set) var reversing: Set<DeckID> = []
    private var cueHeld: Set<DeckID> = []
    private(set) var shifted = false

    mutating func consume(_ bytes: [UInt8]) -> [Event] {
        guard bytes.count == 25, bytes.first == 1 else { return [] }
        let report = TraktorModularReport(current: bytes, previous: previous)
        previous = bytes
        shifted = report.down(1, 0x01)
        var events: [Event] = []
        if report.pressed(4, 0x80) {
            for deck in decks {
                if reversing.remove(deck) != nil { events.append(.reverse(deck, false)) }
                if cueHeld.remove(deck) != nil { events.append(.cue(deck, false)) }
            }
            decks = decks[0] == .a ? [.c, .d] : [.a, .b]
            return events
        }

        for (side, deck) in decks.enumerated() {
            let left = side == 0
            if report.pressed(1, left ? 0x02 : 0x08) { events.append(.action(left ? .playA : .playB, deck)) }
            if report.pressed(1, left ? 0x04 : 0x10) { events.append(.action(left ? .syncA : .syncB, deck)) }
            if let down = report.edge(1, left ? 0x20 : 0x80) {
                if down {
                    cueHeld.insert(deck)
                    events.append(.cue(deck, true))
                } else if cueHeld.remove(deck) != nil {
                    events.append(.cue(deck, false))
                }
            }
            if let down = report.edge(left ? 1 : 2, left ? 0x40 : 0x01) {
                if down {
                    reversing.insert(deck)
                    events.append(.reverse(deck, true))
                } else if reversing.remove(deck) != nil {
                    events.append(.reverse(deck, false))
                }
            }
            for (index, direction) in [-1, 1].enumerated() where report.pressed(2, 0x02 << (side * 2 + index)) {
                events.append(.nudge(deck, direction, shifted: shifted))
            }
            for (slot, field) in Self.hotcues[side].enumerated() where report.pressed(field.0, field.1) {
                events.append(.hotcue(deck, slot, delete: shifted))
            }
            if report.pressed(5, 0x04 << side) { events.append(.action(left ? .loopA : .loopB, deck)) }
            if report.pressed(5, 0x10 << side) { events.append(shifted ? .browserView : .load(deck)) }
            let loop = report.detents(7, side: side)
            if loop != 0 { events.append(.loopSize(deck, loop, shifted: shifted)) }
            let browse = report.detents(8, side: side)
            if browse != 0 { events.append(.browse(browse, groups: shifted)) }
            for (index, target) in decks.enumerated() where report.pressed(left ? 4 : 5, (left ? 0x20 : 1) << index) {
                events.append(.fxAssign(side, target))
            }
            for (knob, field) in Self.fxButtons[side].enumerated() {
                if report.pressed(field.0, field.1) { events.append(.fxEnable(side, knob == 0 ? nil : knob - 1)) }
                if let value = report.pot(21 - knob * 4 + side * 2) { events.append(.fxPot(side, knob, value)) }
            }
        }
        return events
    }
}

enum TraktorModularLights {
    static func color(_ state: DeckPlaybackSnapshot, frames: UInt64?) -> UInt8 {
        guard let pulse = ControllerPlaybackLights.levels(state: state, frameCount: frames) else { return 0 }
        if let amber = pulse.amber, amber > 0.08 { return amber > 0.45 ? 0x0e : 0x0c }
        let blue = pulse.blue * (pulse.amber == nil ? 1 : 0.35)
        return blue > 0.45 ? 0x2e : (blue > 0.08 ? 0x2c : 0)
    }

    static func z1(
        _ snapshot: PlaybackSnapshot, controls: Z1MK2Controls, frames: (DeckID) -> UInt64?, enabled: Set<DeckID>
    ) -> [UInt8] {
        let thresholds: [Double] = [0.012, 0.025, 0.05, 0.1, 0.16, 0.25, 0.4, 0.63, 0.8, 1]
        var bytes: [UInt8] = [0x80] + .init(repeating: 0, count: 46)
        let choices: [S2MixerFX] = [.reverb, .delay, .gater, .flanger, .filter]
        for (index, choice) in choices.enumerated() { bytes[28 + index] = choice == controls.choice ? 0x2e : 0x2c }
        for (side, deck) in controls.decks.enumerated() {
            let state = snapshot[deck]
            for (segment, threshold) in thresholds.enumerated() {
                bytes[1 + side * 10 + segment] = state.mixer.peak >= threshold ? 0x7e : 0
            }
            bytes[21 + side * 3] = 0x2e
            bytes[26 + side] = enabled.contains(deck) ? 0x2e : 0x2c
            bytes[33 + side] = state.mixer.cue ? 0x0e : 0x0c
            let start = 35 + side * 6
            bytes.replaceSubrange(
                start..<(start + 6), with: repeatElement(color(state, frames: frames(deck)), count: 6))
        }
        return bytes
    }

    struct X1Feedback {
        var cues: [DeckID: Set<Int>] = [:]
        var cueHeld: Set<DeckID> = []
        var fxDecks: [Set<DeckID>] = [[], []]
        var fxEnabled: [Bool] = [true, true]
        var fxSlots: [Set<Int>] = [[], []]
    }

    static func x1(
        _ snapshot: PlaybackSnapshot, controls: X1MK3Controls, frames: (DeckID) -> UInt64?, feedback: X1Feedback
    ) -> [UInt8] {
        let hotcues = [[20, 21, 16, 17], [22, 23, 18, 19]]
        var bytes: [UInt8] = [0x80] + .init(repeating: 0, count: 49)
        bytes[1] = controls.shifted ? 0x46 : 0
        for (side, deck) in controls.decks.enumerated() {
            let state = snapshot[deck]
            bytes[2 + side] = state.loopEnabled ? 0x7e : 0
            bytes[4 + side * 2] = state.phase.active ? 0x1e : 0x1c
            bytes[5 + side * 2] = state.synced ? 0x2e : 0x2c
            bytes[8 + side * 2] = feedback.cueHeld.contains(deck) ? 0x0e : 0x0c
            bytes[9 + side * 2] = controls.reversing.contains(deck) ? 0x12 : 0x10
            for (slot, index) in hotcues[side].enumerated() {
                bytes[index] = feedback.cues[deck]?.contains(slot) == true ? 0x2e : 0
            }
            for slot in 0..<3 {
                bytes[28 + side - slot * 2] = feedback.fxSlots[side].contains(slot) ? 0x32 : 0x30
            }
            bytes[30 + side] = feedback.fxEnabled[side] ? 0x32 : 0x30
            for (index, target) in controls.decks.enumerated() {
                bytes[32 + side * 3 + index] = feedback.fxDecks[side].contains(target) ? 0x32 : 0x30
            }
            let start = 37 + side * 7
            bytes.replaceSubrange(
                start..<(start + 6), with: repeatElement(color(state, frames: frames(deck)), count: 6))
        }
        return bytes
    }
}
