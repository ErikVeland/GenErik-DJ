import Foundation
import TDJCore

struct TraktorFactoryLights {
    private var bytes: [UInt8]
    private let model: TraktorFactoryModel

    init(_ model: TraktorFactoryModel) {
        self.model = model
        bytes = .init(repeating: 0, count: model.lightSizes.reduce(0, +) - model.lightSizes.count)
    }

    mutating func lamp(_ lamp: TraktorFactoryProfile.Lamp, level: UInt8) {
        switch lamp {
        case .mono(let at): set(at, level)
        case .rgb(let at): rgb(at, red: 0, green: level / 4, blue: level)
        case .palette(let at): set(at, palette(level: Double(level) / 127, base: 44))
        }
    }

    mutating func pulse(_ lamp: TraktorFactoryProfile.Pulse, blue: Double, amber: Double?) {
        let warning = (amber ?? 0) > 0.03
        let blueLevel = warning ? 0 : UInt8((blue * 127).rounded())
        let amberLevel = warning ? UInt8(((amber ?? 0) * 127).rounded()) : 0
        switch lamp {
        case .mono(let beat, let warningLamp):
            set(beat, blueLevel)
            if warning { set(warningLamp, amberLevel) }
        case .rgb(let at):
            if warning { rgb(at, red: amberLevel, green: amberLevel / 2, blue: 0) }
            else { rgb(at, red: 0, green: blueLevel / 4, blue: blueLevel) }
        case .paired(let blue, let amber, let count, let stride):
            for i in 0..<count {
                set(blue + i * stride, blueLevel)
                set(amber + i * stride, amberLevel)
            }
        case .palette(let first, let count):
            let color = warning ? palette(level: amber ?? 0, base: 12) : palette(level: blue, base: 44)
            for i in 0..<count { set(first + i, color) }
        }
    }

    mutating func meter(first: Int, count: Int, peak: Double) {
        let floor = -36.0
        for i in 0..<count {
            let db = floor + Double(i) * -floor / Double(max(1, count - 1))
            set(first + i, peak >= pow(10, db / 20) ? 127 : 0)
        }
    }

    var reports: [[UInt8]] {
        var start = 0
        return model.lightSizes.enumerated().map { index, size in
            let end = start + size - 1
            let report = [UInt8(0x80 + index)] + bytes[start..<end]
            start = end
            return report
        }
    }

    private mutating func rgb(_ at: Int, red: UInt8, green: UInt8, blue: UInt8) {
        if model == .f1 {
            set(at, blue)
            set(at + 1, red)
            set(at + 2, green)
        } else {
            set(at, red)
            set(at + 1, green)
            set(at + 2, blue)
        }
    }

    private mutating func set(_ at: Int, _ value: UInt8) {
        assert(bytes.indices.contains(at))
        if bytes.indices.contains(at) { bytes[at] = value }
    }

    private func palette(level: Double, base: UInt8) -> UInt8 {
        guard level > 0.03 else { return 0 }
        return base + UInt8((min(1, level) * 3).rounded())
    }
}

#if os(iOS)
    extension ReplicaModel {
        func factoryLights(_ session: TraktorFactorySession, snapshot: PlaybackSnapshot) -> [[UInt8]] {
            let profile = session.controls.profile
            let stateKey = \ReplicaModel.[factory: session.model]
            let native = self[keyPath: stateKey]
            var reports = TraktorFactoryLights(session.model)
            let samples = playback.core.playingPads

            func sampleLevel(_ slot: Int) -> UInt8 {
                if samples & (1 << slot) != 0 { return 127 }
                return s2SampleSlots[slot] == nil ? 0 : 25
            }

            for light in profile.lights {
                let deck = session.deck(light.target)
                let state = snapshot[deck]
                let unit = session.fxUnit(light.target)
                let active: Bool
                switch light.control {
                case .play: active = state.phase.active
                case .cue: active = session.heldCues.contains(deck) || (!state.phase.active && state.generation != 0)
                case .sync: active = state.synced
                case .keylock: active = state.keylock
                case .flux: active = state.fluxEnabled
                case .reverse: active = session.reversing.contains(deck)
                case .shift: active = session.shifted(light.target)
                case .loop, .loopMark: active = state.loopEnabled
                case .load: active = state.generation != 0
                case .browser: active = browserVisible
                case .preview: active = native.ownsPreview
                case .layer(let selected): active = selected.map { $0 == deck } ?? (deck.transportIndex >= 2)
                case .hotcues:
                    active = session.model == .x1MK1 ? session.hotcueMode
                        : !session.sampleDecks.contains(deck) && native.slices[deck] == nil
                case .samples: active = session.sampleDecks.contains(deck)
                case .freeze: active = native.slices[deck] != nil
                case .quantize: active = native.quantize
                case .grid: active = s2Grids[deck] != nil
                case .fxButton(let slot):
                    active = slot == 0 ? native.fx[unit].enabled : native.fx[unit].slots.contains(slot - 1)
                case .fxAssign(let unit): active = native.fx[unit].decks.contains(deck)
                case .mixerFX(let index): active = index == session.mixerFX
                case .mixerButton(.cueA): active = state.mixer.cue
                case .mixerButton(.filterToggleA): active = state.mixer.filterEnabled
                case .pad(let slot):
                    if session.sampleDecks.contains(deck) {
                        reports.lamp(light.lamp, level: sampleLevel(Int(deck.transportIndex) * 8 + slot))
                    } else if let slice = native.slices[deck] {
                        reports.lamp(light.lamp, level: slice.held.last == slot ? 127 : 40)
                    } else {
                        let marked = loaded[deck].flatMap { performance.cues[$0]?[slot] } != nil
                        reports.lamp(light.lamp, level: marked ? 60 : 0)
                    }
                    continue
                case .sample(let slot):
                    reports.lamp(light.lamp, level: sampleLevel(slot))
                    continue
                default: active = false
                }
                reports.lamp(light.lamp, level: active ? 127 : 5)
            }
            for (side, pulse) in profile.pulses.enumerated() {
                let state = snapshot[session.decks[side]]
                let frames = playback.core.asset(generation: state.generation)?.frames
                if let levels = ControllerPlaybackLights.levels(state: state, frameCount: frames) {
                    reports.pulse(pulse, blue: levels.blue, amber: levels.amber)
                }
            }
            for meter in profile.meters {
                reports.meter(first: meter.first, count: meter.count, peak: snapshot[meter.0].mixer.peak)
            }
            return reports.reports
        }
    }
#endif
