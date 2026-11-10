import TDJCore

enum S2MK2Lights {
    private static let meterLevels = [0.126, 0.251, 0.501, 0.794]

    static func report(
        snapshot: PlaybackSnapshot, controls: S2MK2Controls, feedback: S4MK2Lights.Feedback,
        cueKinds: [DeckID: [Int: PerformanceCueKind]] = [:]
    ) -> [UInt8] {
        var bytes: [UInt8] = .init(repeating: 0, count: 70)
        bytes[0] = 0x83
        bytes[0x1d] = 0x64
        func lamp(_ active: Bool, dim: UInt8 = 4) -> UInt8 { active ? 0x7f : dim }

        for (side, deck) in DeckID.primary.enumerated() {
            let state = snapshot[deck]
            let loaded = state.phase != .empty
            let playing = state.phase.active
            let remix = controls.samples.contains(deck)
            let transport = 37 + 0x19 + side * 4
            let loop = 0x21 + side * 2
            bytes[0x19 + side] = lamp(loaded)
            bytes[0x1b + side * 4] = lamp(state.mixer.cue)
            bytes[0x17 + side] = lamp(remix)
            bytes[side == 0 ? 0x20 : 0x25] = lamp(state.fluxEnabled)
            bytes[loop] = lamp(state.loopEnabled || feedback.loopMarked[deck] == true)
            bytes[loop + 1] = lamp(state.loopEnabled)
            bytes[transport] = lamp(controls.shifts.contains(deck))
            bytes[transport + 1] = lamp(state.synced || controls.gridEditing.contains(deck))
            bytes[transport + 2] = lamp(feedback.cueHeld[deck] == true || (loaded && !playing))
            bytes[transport + 3] = lamp(playing)
            for (segment, threshold) in meterLevels.enumerated() {
                bytes[1 + side * 5 + segment] = lamp(state.mixer.peak >= threshold, dim: 0)
            }
            bytes[5 + side * 5] = lamp(state.mixer.peak >= 1, dim: 0)
            for unit in 0..<2 {
                bytes[0x0f + side * 2 + unit] = lamp(feedback.fxDecks[unit].contains(deck))
            }
            let pads = 38 + side * 12
            for slot in 0..<4 {
                let offset = pads + slot * 3
                if let looping = feedback.sliceModes[deck] {
                    bytes[offset + (looping ? 1 : 2)] = feedback.heldSlices[deck] == slot ? 0x7f : 0x30
                } else if remix {
                    let sample = S2MK3Controls.sampleSlot(deck: deck, pad: slot)
                    if feedback.samples & (1 << sample) != 0 {
                        bytes[offset + 1] = 0x7f
                    } else if feedback.sampleSlots.contains(sample) {
                        bytes[offset] = 0x30
                        bytes[offset + 1] = 0x18
                    }
                } else {
                    switch cueKinds[deck]?[slot] {
                    case .cue: bytes[offset + 2] = 0x30
                    case .loop: bytes[offset + 1] = 0x30
                    case .grid:
                        bytes[offset] = 0x30
                        bytes[offset + 1] = 0x30
                        bytes[offset + 2] = 0x30
                    case nil: break
                    }
                }
            }
            if let pulse = ControllerPlaybackLights.levels(
                state: state, frameCount: feedback.frames[deck], options: feedback.lighting
            ) {
                let offset = pads + 9
                let amber = pulse.amber ?? 0
                if amber > 0.03 {
                    bytes[offset] = UInt8((amber * 127).rounded())
                    bytes[offset + 1] = UInt8((amber * 45).rounded())
                    bytes[offset + 2] = 0
                } else {
                    let blue = UInt8((pulse.blue * (pulse.amber == nil ? 127 : 44.45)).rounded())
                    if blue > bytes[offset + 2] {
                        bytes[offset] = 0
                        bytes[offset + 1] = 0
                        bytes[offset + 2] = blue
                    }
                }
            }
        }

        for unit in 0..<2 {
            let start = 0x0b + unit * 8
            bytes[start] = lamp(feedback.fxActive[unit])
            for slot in 0..<3 { bytes[start + slot + 1] = lamp(feedback.fxSlots[unit].contains(slot)) }
        }
        return bytes
    }
}
