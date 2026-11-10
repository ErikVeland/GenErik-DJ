import TDJCore

enum S2MK1Lights {
    private struct DeckLights {
        let play, cue, sync, shift, loaded, pfl, sample, reset, loopIn, loopOut, meter, peak, blue, green: Int
    }

    private static let decks = [
        DeckLights(
            play: 0x03, cue: 0x07, sync: 0x04, shift: 0x08, loaded: 0x1f, pfl: 0x20, sample: 0x35, reset: 0x06,
            loopIn: 0x02, loopOut: 0x05, meter: 0x15, peak: 0x01, blue: 0x10, green: 0x0c),
        DeckLights(
            play: 0x23, cue: 0x27, sync: 0x24, shift: 0x28, loaded: 0x1e, pfl: 0x1d, sample: 0x34, reset: 0x26,
            loopIn: 0x22, loopOut: 0x21, meter: 0x11, peak: 0x25, blue: 0x30, green: 0x2c),
    ]
    private static let thresholds: [Double] = [0.063, 0.16, 0.4, 0.8]

    static func report(
        snapshot: PlaybackSnapshot, controls: S2MK1Controls, feedback: S4MK2Lights.Feedback,
        cueKinds: [DeckID: [Int: PerformanceCueKind]] = [:]
    ) -> [UInt8] {
        var bytes: [UInt8] = [0x80] + .init(repeating: 0, count: 61)
        func lamp(_ on: Bool) -> UInt8 { on ? 0x1f : 0 }
        for (side, deck) in DeckID.primary.enumerated() {
            let state = snapshot[deck]
            let lights = decks[side]
            let samples = controls.samples.contains(deck)
            bytes[lights.play] = lamp(state.phase.active)
            bytes[lights.cue] = lamp(feedback.cueHeld[deck] == true || state.phase == .paused)
            bytes[lights.sync] = lamp(state.synced)
            bytes[lights.shift] = lamp(controls.shifts.contains(deck))
            bytes[lights.loaded] = lamp(state.phase != .empty)
            bytes[lights.pfl] = lamp(state.mixer.cue)
            bytes[lights.sample] = lamp(samples)
            bytes[lights.reset] = lamp(controls.tempoLocked.contains(deck))
            bytes[lights.loopIn] = lamp(state.loopEnabled || feedback.loopMarked[deck] == true)
            bytes[lights.loopOut] = lamp(state.loopEnabled)
            bytes[lights.peak] = lamp(state.mixer.peak >= 1)
            for (index, threshold) in thresholds.enumerated() {
                bytes[lights.meter + index] = lamp(state.mixer.peak >= threshold)
            }
            for slot in 0..<4 {
                if samples {
                    let sample = S2MK3Controls.sampleSlot(deck: deck, pad: slot)
                    if feedback.sampleSlots.contains(sample) {
                        bytes[lights.green - slot] = feedback.samples & (1 << sample) != 0 ? 0x1f : 0x05
                    }
                } else if let kind = cueKinds[deck]?[slot] {
                    let channel = kind == .loop ? lights.green : lights.blue
                    bytes[channel - slot] = 0x0c
                }
            }
            if let pulse = ControllerPlaybackLights.levels(state: state, frameCount: feedback.frames[deck]) {
                let offset = lights.blue - 3
                let blue = UInt8((pulse.blue * (pulse.amber == nil ? 24 : 8)).rounded())
                if blue >= 4 {
                    bytes[lights.green - 3] = 0
                    bytes[offset] = max(bytes[offset], blue)
                }
                bytes[0x33] = max(bytes[0x33], UInt8(((pulse.amber ?? 0) * 31).rounded()))
            }
        }
        for unit in 0..<2 {
            let focus = unit == 0 ? 0x1c : 0x39
            bytes[focus] = lamp(feedback.fxActive[unit])
            for slot in 0..<3 { bytes[focus - slot - 1] = lamp(feedback.fxSlots[unit].contains(slot)) }
            bytes[0x3d - unit] = lamp(feedback.fxDecks[unit].contains(.a))
            bytes[0x3b - unit] = lamp(feedback.fxDecks[unit].contains(.b))
        }
        return bytes
    }
}
