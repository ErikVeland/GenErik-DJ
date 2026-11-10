import TDJCore

enum S4MK1Lights {
    private static let digits: [UInt8] = [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f]
    private static let meterLevels: [Double] = [0.016, 0.063, 0.126, 0.251, 0.501, 0.794]

    static func report(
        snapshot: PlaybackSnapshot, controls: S4MK1Controls, feedback: S4MK2Lights.Feedback,
        cueKinds: [DeckID: [Int: PerformanceCueKind]], snap: Bool, browsing: Bool, tempo: [Double] = [0.5, 0.5],
        clockDeck: DeckID? = nil, recorder: PerformanceLoopRecorderState = [], fxGroups: [Bool] = [false, false],
        copySource: S4MK1CopyTarget? = nil
    ) -> [UInt8] {
        var lights = [UInt8](repeating: 0, count: 163)
        func set(_ id: Int, _ active: Bool, dim: UInt8 = 0) { lights[id - 1] = active ? 31 : dim }
        func level(_ value: Double) -> UInt8 { UInt8((value * 31).rounded()) }
        set(1, feedback.quantize)
        set(2, feedback.preview)
        set(3, clockDeck == nil)
        set(4, snap)
        set(6, clockDeck == nil, dim: 2)
        set(8, !recorder.intersection([.armed, .recording, .overdubbing]).isEmpty, dim: 2)
        set(9, recorder.contains(.stored), dim: 2)
        set(7, snap, dim: 2)
        set(10, feedback.quantize, dim: 2)
        set(11, browsing || controls.copying, dim: 2)
        let flash = Int(snapshot.outputFrame / UInt64(max(1, snapshot.sampleRate / 4))) % 2 == 0
        let recorderPlay =
            controls.copying
            ? copySource == .recordedLoop || (copySource == nil && recorder.contains(.stored) && flash)
            : recorder.contains(.playing)
        set(12, recorderPlay, dim: 2)
        set(13, recorder.contains(.hasUndo) || recorder.contains(.stored) && !recorder.contains(.playing), dim: 2)

        var pulses: [DeckID: (blue: Double, amber: Double?)] = [:]
        for (channel, deck) in DeckID.allCases.enumerated() {
            let state = snapshot[deck]
            let base = 14 + 13 * channel
            set(base, state.mixer.crossfaderAssignment == .right)
            set(base + 1, state.mixer.crossfaderAssignment == .left)
            for (segment, threshold) in meterLevels.enumerated() {
                set(base + 2 + segment, state.mixer.peak >= threshold)
            }
            set(base + 8, state.mixer.peak >= 1)
            set(base + 9, controls.layers.contains(deck))
            let cueTarget = S4MK1CopyTarget.deck(deck)
            let cueLight =
                controls.copying
                ? copySource == cueTarget || (flash && (copySource != nil || state.phase != .empty))
                : controls.browsing ? flash : state.mixer.cue
            set(base + 10, cueLight, dim: 2)
            for unit in 0..<2 { set(base + 11 + unit, feedback.fxDecks[unit].contains(deck), dim: 2) }
            pulses[deck] = ControllerPlaybackLights.levels(
                state: state, frameCount: feedback.frames[deck], options: feedback.lighting
            )
        }
        lights[4] = level(pulses.values.compactMap(\.amber).max() ?? 0)

        for (side, deck) in controls.layers.enumerated() {
            let base = side * 44
            let state = snapshot[deck]
            let outer = deck.transportIndex >= 2
            set(base + 74, state.phase != .empty, dim: 2)
            set(base + 75, outer, dim: 2)
            set(base + 76, state.loopEnabled || feedback.loopMarked[deck] == true, dim: 2)
            set(base + 77, state.loopEnabled, dim: 2)
            set(base + 78, controls.shifts.contains(deck), dim: 2)
            set(base + 79, state.synced, dim: 2)
            set(base + 80, feedback.cueHeld[deck] == true || (!state.phase.active && state.phase != .empty), dim: 2)
            set(base + 81, state.phase.active, dim: 2)
            if let position = controls.tempoPosition(side: side) {
                let locked = controls.tempoLocked.contains(deck)
                let difference = tempo[side] - position
                let centered: UInt8 = abs(position - 0.5) < 0.02 ? 2 : 0
                set(base + 82, locked || difference < -0.02, dim: centered)
                set(base + 83, locked || difference > 0.02, dim: centered)
            }
            set(base + 84, clockDeck == deck)
            set(base + 85, state.keylock)
            set(base + 86, !outer)
            set(base + 87, outer)
            set(base + 89, state.phase.active && state.mixer.volume > 0)
            for slot in 0..<4 {
                let blue = base + 66 + 2 * slot
                if let kind = cueKinds[deck]?[slot] { lights[blue - (kind == .loop ? 0 : 1)] = 12 }
                let sample = S4MK1Controls.sampleSlot(deck: deck, pad: slot)
                let available = feedback.sampleSlots.contains(sample)
                let sampleTarget = S4MK1CopyTarget.sample(sample)
                let sampleLight =
                    controls.copying
                    ? copySource == sampleTarget || (flash && (copySource == nil ? available : !available))
                    : controls.browsing ? flash && !available : feedback.samples & (1 << sample) != 0
                set(base + 90 + slot, sampleLight, dim: available ? 12 : 2)
            }
            if let pulse = pulses[deck] {
                let strength = level(pulse.blue * (pulse.amber == nil ? 1 : 0.35))
                if strength >= 4 {
                    lights[base + 71] = max(lights[base + 71], strength)
                    lights[base + 72] = 0
                }
            }
            if state.phase != .empty, let beats = feedback.loops[deck], PerformancePreparation.loopSizes.contains(beats)
            {
                let value = Int(beats < 1 ? (1 / beats).rounded() : beats)
                let first = value >= 10 ? digits[value / 10] : 0
                let second = digits[value % 10] | (beats < 1 ? 0x80 : 0)
                for segment in 0..<8 {
                    set(base + 94 + segment, first & (1 << segment) != 0)
                    set(base + 102 + segment, second & (1 << segment) != 0)
                }
            }
        }

        for unit in 0..<2 {
            let base = 154 + unit * 5
            set(base, feedback.fxActive[unit], dim: 2)
            for slot in 0..<3 { set(base + 1 + slot, feedback.fxSlots[unit].contains(slot), dim: 2) }
            set(base + 4, fxGroups[unit], dim: 2)
        }
        return pack(lights)
    }

    private static func pack(_ lights: [UInt8]) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 103)
        report[0] = 0x80
        for (index, value) in lights.enumerated() {
            let bit = index * 5
            let byte = 1 + bit / 8
            let shift = bit % 8
            report[byte] |= value << shift
            if shift > 3 { report[byte + 1] |= value >> (8 - shift) }
        }
        return report
    }
}
