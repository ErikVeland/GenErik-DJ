import Foundation
import TDJCore

enum S4MK2Lights {
    struct Feedback {
        var frames: [DeckID: UInt64] = [:]
        var cues: [DeckID: Set<Int>] = [:]
        var loops: [DeckID: Double] = [:]
        var loopMarked: [DeckID: Bool] = [:]
        var fxDecks: [Set<DeckID>] = [[], []]
        var fxActive = [false, false]
        var fxSlots: [Set<Int>] = [[], []]
        var sampleSlots: Set<Int> = []
        var samples: UInt32 = 0
        var master = (left: false, right: false)
        var preview = false
        var recording = false
        var quantize = true
    }

    private static let digits: [UInt8] = [0xfc, 0x0c, 0xda, 0x9e, 0x2e, 0xb6, 0xf6, 0x1c, 0xfe, 0xbe]
    private static let meterLevels: [Double] = [0.016, 0.063, 0.126, 0.251, 0.501, 0.794]

    static func report(snapshot: PlaybackSnapshot, controls: S4MK2Controls, feedback: Feedback) -> [UInt8] {
        var bytes: [UInt8] = .init(repeating: 0, count: 175)
        bytes[0] = 0x83
        let deckBase = 52
        let mixerBase = 114
        func lamp(_ active: Bool, dim: UInt8 = 0) -> UInt8 { active ? 0x7f : dim }
        bytes[0x2a] = 0x64
        bytes[0x31] = lamp(feedback.quantize)
        bytes[0x34] = lamp(feedback.recording)
        bytes[deckBase + 0x3d] = lamp(feedback.preview)
        bytes[mixerBase + 0x3b] = lamp(feedback.master.left)
        bytes[mixerBase + 0x3c] = lamp(feedback.master.right)

        for (index, deck) in [DeckID.c, .a, .b, .d].enumerated() {
            let state = snapshot[deck]
            let meter = 1 + index * 8
            for (segment, level) in meterLevels.enumerated() {
                bytes[meter + segment] = lamp(state.mixer.peak >= level)
            }
            bytes[meter + 6] = lamp(state.mixer.peak >= 1)
            bytes[meter + 7] = lamp(state.phase != .empty, dim: 0x04)
            bytes[mixerBase + 0x17 + index] = lamp(state.mixer.cue, dim: 0x04)
            for unit in 0..<2 {
                bytes[mixerBase + 5 + index * 2 + unit] = lamp(feedback.fxDecks[unit].contains(deck), dim: 0x04)
            }
        }

        for (side, deck) in controls.layers.enumerated() {
            let state = snapshot[deck]
            let transport = deckBase + 0x1d + 8 * side
            let playing = state.phase.active
            bytes[transport] = lamp(controls.shifts.contains(deck), dim: 0x04)
            bytes[transport + 1] = lamp(state.synced, dim: 0x04)
            bytes[transport + 2] = lamp(!playing && state.phase != .empty, dim: 0x04)
            bytes[transport + 3] = lamp(playing, dim: 0x04)
            bytes[deckBase + 0x29 + side * 2] = lamp(state.loopEnabled || feedback.loopMarked[deck] == true, dim: 4)
            bytes[deckBase + 0x2a + side * 2] = lamp(state.loopEnabled, dim: 4)
            bytes[deckBase + 0x2f + side * 6] = lamp(state.keylock, dim: 4)
            bytes[deckBase + 0x39 + side * 2] = lamp(state.fluxEnabled, dim: 4)
            let outer = deck.transportIndex >= 2
            bytes[deckBase + 0x2e + side * 6] = lamp(!outer)
            bytes[deckBase + 0x31 + side * 6] = lamp(outer)
            bytes[mixerBase + (side == 0 ? 0x13 : 0x16)] = lamp(outer, dim: 5)
            bytes[mixerBase + 0x14 + side] = lamp(state.phase != .empty, dim: 4)

            for slot in 0..<4 {
                let offset = deckBase + 1 + side * 12 + slot * 3
                if feedback.cues[deck]?.contains(slot) == true { bytes[offset + 2] = 0x30 }
                let sample = side * 8 + slot
                bytes[deckBase + 0x19 + side * 8 + slot] = lamp(
                    feedback.samples & (1 << sample) != 0, dim: feedback.sampleSlots.contains(sample) ? 0x20 : 4)
            }
            if let pulse = ControllerPlaybackLights.levels(state: state, frameCount: feedback.frames[deck]) {
                let offset = deckBase + 10 + side * 12
                let amber = pulse.amber ?? 0
                if amber > 0.03 {
                    bytes[offset] = UInt8((amber * 127).rounded())
                    bytes[offset + 1] = UInt8((amber * 45).rounded())
                    bytes[offset + 2] = 0
                } else {
                    let level = pulse.blue * (pulse.amber == nil ? 1 : 0.35)
                    bytes[offset + 2] = max(bytes[offset + 2], UInt8((level * 127).rounded()))
                }
            }

            if state.phase != .empty, let beats = feedback.loops[deck], PerformancePreparation.loopSizes.contains(beats)
            {
                let value = Int(beats < 1 ? (1 / beats).rounded() : beats)
                let start = mixerBase + 0x1b + side * 16
                let first = value >= 10 ? digits[value / 10] : 0
                let second = digits[value % 10] | (beats < 1 ? 1 : 0)
                for segment in 0..<8 {
                    bytes[start + segment] = lamp(first & (1 << segment) != 0)
                    bytes[start + 8 + segment] = lamp(second & (1 << segment) != 0)
                }
            }
        }

        for unit in 0..<2 {
            let base = mixerBase + 1 + unit * 12
            bytes[base] = lamp(feedback.fxActive[unit], dim: 4)
            for slot in 0..<3 {
                bytes[base + 1 + slot] = lamp(feedback.fxSlots[unit].contains(slot), dim: 4)
            }
        }
        return bytes
    }
}
