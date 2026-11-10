import TDJCore

struct BeatpadLight: Equatable {
    let channel, note, value: UInt8
    var key: UInt16 { UInt16(channel) << 8 | UInt16(note) }
}

enum BeatpadLights {
    struct Feedback {
        var frames: [DeckID: UInt64] = [:]
        var cues: [DeckID: Set<Int>] = [:]
        var heldCue: Set<DeckID> = []
        var effects: Set<DeckID> = []
        var sampleSlots: Set<Int> = []
        var playingSamples: UInt32 = 0
        var recording = false
        var lighting = ControllerPlaybackLights.Options()
    }

    static func report(snapshot: PlaybackSnapshot, controls: BeatpadControls, feedback: Feedback) -> [BeatpadLight] {
        var lights = [BeatpadLight(channel: 4, note: 0x41, value: feedback.recording ? 127 : 0)]
        for (side, deck) in DeckID.primary.enumerated() {
            let state = snapshot[deck]
            let input = controls.sides[side]
            func set(_ note: UInt8, _ value: UInt8) {
                lights.append(.init(channel: UInt8(side), note: note, value: value))
            }
            func button(_ note: UInt8, _ enabled: Bool) { set(note, enabled ? 127 : 0) }
            button(0x44, state.loopEnabled)
            button(0x47, feedback.effects.contains(deck))
            button(0x5d, state.synced && state.phase != .empty)
            button(0x5e, feedback.heldCue.contains(deck) || (!state.phase.active && state.phase != .empty))
            button(0x60, state.phase.active)
            button(0x61, state.mixer.cue)
            button(0x62, state.phase != .empty)
            button(0x22, input.faderStart)
            set(0x66, UInt8(min(8, max(0, (state.mixer.peak * 8).rounded(.up)))))
            set(0x67, 0)
            let pulse = ControllerPlaybackLights.levels(
                state: state, frameCount: feedback.frames[deck], options: feedback.lighting
            )
            let amber = (pulse?.amber ?? 0) >= 0.18
            button(0x68, !amber && (pulse?.blue ?? 0) >= 0.12)
            for slot in 0..<4 {
                set(0x69 + UInt8(slot), amber ? 4 : 0)
                let sample = side * 4 + slot
                if input.mode == .samples {
                    let colour: UInt8 =
                        feedback.playingSamples & (1 << sample) != 0 ? 8 : feedback.sampleSlots.contains(sample) ? 1 : 0
                    set(0x58 + UInt8(slot), colour)
                } else {
                    button(0x4c + UInt8(slot), feedback.cues[deck]?.contains(slot) == true)
                }
            }
        }
        return lights
    }
}
