import TDJCore

enum S4MK3Lights {
    static func panel(
        snapshot: PlaybackSnapshot, controls: S4MK3Controls, feedback: S4MK2Lights.Feedback, stems: [DeckID: Set<Int>] = [:]
    ) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 95)
        bytes[0] = 0x80
        func lamp(_ on: Bool, _ color: UInt8 = 68) -> UInt8 { color + (on ? 3 : 1) }
        bytes[94] = feedback.quantize ? 127 : 0
        for (side, deck) in controls.layers.enumerated() {
            let left = side == 0
            let state = snapshot[deck]
            let first = left ? 0 : 23
            let palette: UInt8 = deck.transportIndex < 2 ? 44 : 12
            bytes[1 + (left ? 55 : 66)] = lamp(state.phase.active, 28)
            bytes[1 + (left ? 8 : 31)] = lamp(feedback.cueHeld[deck] == true || state.phase == .paused, 12)
            bytes[1 + (left ? 14 : 37)] = lamp(state.synced, 12)
            bytes[1 + (left ? 59 : 70)] = lamp(controls.shifts.contains(deck))
            bytes[1 + (left ? 61 : 72)] = lamp(state.fluxEnabled)
            bytes[1 + (left ? 60 : 71)] = lamp(controls.reversing.contains(deck))
            bytes[1 + (left ? 18 : 41)] = lamp(controls.gridHeld.contains(deck))
            bytes[1 + (left ? 16 : 39)] = lamp(true)
            bytes[1 + (left ? 22 : 45)] = lamp(feedback.preview)
            bytes[1 + (left ? 12 : 35)] = lamp(deck.transportIndex < 2, 44)
            bytes[1 + (left ? 13 : 36)] = lamp(deck.transportIndex >= 2, 12)
            let stemMode = controls.stems.contains(deck) && stems[deck] != nil
            bytes[1 + (left ? 9 : 32)] = lamp(!controls.samples.contains(deck) && !stemMode)
            bytes[1 + (left ? 10 : 33)] = lamp(stemMode, 44)
            bytes[1 + (left ? 58 : 69)] = lamp(stemMode && controls.stemMuteHeld.contains(deck), 44)
            bytes[1 + (left ? 57 : 68)] = lamp(controls.samples.contains(deck))
            for slot in 0..<8 {
                let sample = Int(deck.transportIndex) * 8 + slot
                if let looping = feedback.sliceModes[deck] {
                    bytes[1 + first + slot] = lamp(feedback.heldSlices[deck] == slot, looping ? 28 : 44)
                } else if stemMode, let muted = stems[deck] {
                    let on = slot < 4 ? !muted.contains(slot) : controls.stemContacts[deck] == slot - 4
                    bytes[1 + first + slot] = lamp(on, [44, 28, 12, 60][slot % 4])
                } else if controls.samples.contains(deck) {
                    if feedback.sampleSlots.contains(sample) {
                        bytes[1 + first + slot] = lamp(feedback.samples & (1 << sample) != 0, 28)
                    }
                } else if feedback.cues[deck]?.contains(slot) == true {
                    bytes[1 + first + slot] = lamp(true, palette)
                }
            }
        }
        for (index, deck) in DeckID.allCases.enumerated() {
            let start = 78 + index * 4
            bytes[start] = lamp(snapshot[deck].mixer.cue, 12)
            for unit in 0..<2 { bytes[start + 1 + unit] = lamp(feedback.fxDecks[unit].contains(deck), 12) }
        }
        for unit in 0..<2 {
            let start = unit == 0 ? 63 : 74
            bytes[start] = lamp(feedback.fxActive[unit], 12)
            for slot in 0..<3 { bytes[start + 1 + slot] = lamp(feedback.fxSlots[unit].contains(slot), 12) }
        }
        return bytes
    }

    static func ring(side: Int, state: DeckPlaybackSnapshot, frames: UInt64?) -> [UInt8] {
        var report: [UInt8] = [0x32, UInt8(side)] + .init(repeating: 0, count: 39)
        guard let pulse = ControllerPlaybackLights.levels(state: state, frameCount: frames) else { return report }
        let amber = pulse.amber ?? 0
        let blue = pulse.blue * (pulse.amber == nil ? 1 : 0.35)
        let level = amber > 0.03 ? amber : blue
        guard level > 0.03 else { return report }
        let palette: UInt8 = amber > 0.03 ? 12 : 44
        let color = palette + UInt8(min(3, Int(level * 4)))
        report[2] = 5
        for index in 9..<report.count { report[index] = color }
        return report
    }
}
