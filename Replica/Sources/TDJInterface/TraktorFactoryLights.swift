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

    mutating func patternLamp(_ lamp: TraktorFactoryProfile.Lamp, color: UInt8) {
        if case .palette(let at) = lamp { set(at, color) }
    }

    mutating func digits(_ number: Int, first: Int, count: Int, width: Int, reversed: Bool = false, fraction: Bool = false) {
        let masks: [UInt8] = [0xfc, 0x0c, 0xda, 0x9e, 0x2e, 0xb6, 0xf6, 0x1c, 0xfe, 0xbe]
        var text = String(number).compactMap(\.wholeNumberValue).map { masks[$0] }
        if fraction { text.insert(0x02, at: 0) }
        if text.count < count { text = .init(repeating: 0, count: count - text.count) + text }
        if reversed { text.reverse() }
        for (digit, mask) in text.prefix(count).enumerated() {
            for segment in 0..<width {
                let bit = segment + (width == 7 ? 1 : 0)
                set(first + digit * width + segment, mask & (1 << bit) != 0 ? 127 : 0)
            }
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
        switch model {
        case .f1:
            set(at, blue)
            set(at + 1, red)
            set(at + 2, green)
        case .d2:
            set(at, blue)
            set(at + 1, green)
            set(at + 2, red)
        default:
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
                if session.model == .x1MK1, session.hotcueMode, let slot = light.control.x1HotcueSlot {
                    let marked = loaded[deck].flatMap { performance.cues[$0]?[slot] } != nil
                    reports.lamp(light.lamp, level: marked ? 127 : 5)
                    continue
                }
                switch light.control {
                case .play: active = state.phase.active
                case .cue: active = session.heldCues.contains(deck) || (!state.phase.active && state.generation != 0)
                case .sync: active = state.synced
                case .microphone: active = session.microphone && playback.factoryCaptureActive(session.audioDevice)
                case .liveInput: active = session.liveInputs.contains(deck) && playback.factoryCaptureActive(session.audioDevice)
                case .timecode: active = session.timecode.contains(deck) && playback.factoryCaptureActive(session.audioDevice)
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
                        : !session.sampleDecks.contains(deck) && !session.loopDecks.contains(deck) && native.slices[deck] == nil
                case .samples: active = session.sampleDecks.contains(deck)
                case .loopPads: active = session.loopDecks.contains(deck)
                case .freeze: active = native.slices[deck] != nil
                case .quantize: active = native.quantize
                case .grid: active = s2Grids[deck] != nil
                case .fxButton(let slot):
                    let pattern = session.patterns[unit]
                    if session.model == .mx2, pattern.mode == 2 {
                        active = (slot == 0 && pattern.enabled) || (slot == 3 && pattern.ducking)
                    } else {
                        active = slot == 0 ? native.fx[unit].enabled : native.fx[unit].slots.contains(slot - 1)
                    }
                case .fxAssign(let unit):
                    let pattern = session.patterns[unit]
                    active = (session.model == .mx2 && pattern.mode == 2 ? pattern.decks : native.fx[unit].decks).contains(deck)
                case .stemPads:
                    reports.patternLamp(light.lamp, color: session.stemDecks.contains(deck) && isStemDeck(deck) ? 46 : 44)
                    continue
                case .stemFilterToggle(let part):
                    active = stemMix(deck).map { !$0.bypassed.contains(part) && abs($0.filters[part]) > 0.01 } ?? false
                case .stopSampleColumn(let part):
                    active = stemMix(deck)?.muted.contains(part) == true
                case .patternPads:
                    let page = session.patterns[unit].page
                    reports.patternLamp(light.lamp, color: page == 1 ? 70 : page == 0 ? 46 : 44)
                    continue
                case .mixerFX(let index): active = index == session.mixerFX
                case .mixerButton(.cueA): active = state.mixer.cue
                case .mixerButton(.filterToggleA): active = state.mixer.filterEnabled
                case .pad(let slot):
                    if session.stemDecks.contains(deck), let mix = stemMix(deck) {
                        reports.lamp(light.lamp, level: mix.muted.contains(slot % 4) ? 12 : 127)
                    } else if session.model == .mx2, let page = session.patterns[unit].page {
                        let step = page * 8 + slot
                        let on = session.patterns[unit].steps & (1 << step) != 0
                        let cursor = Int((snapshot.masterBeat * 4).rounded(.down)) & 15
                        reports.patternLamp(light.lamp, color: cursor == step ? 14 : on ? 30 : 28)
                    } else if session.sampleDecks.contains(deck) {
                        reports.lamp(light.lamp, level: sampleLevel(Int(deck.transportIndex) * 8 + slot))
                    } else if session.loopDecks.contains(deck) {
                        reports.lamp(light.lamp, level: session.rollPads[deck] == slot ? 127 : 28)
                    } else if let slice = native.slices[deck] {
                        reports.lamp(light.lamp, level: slice.held.last == slot ? 127 : 40)
                    } else {
                        let marked = loaded[deck].flatMap { performance.cues[$0]?[slot] } != nil
                        reports.lamp(light.lamp, level: marked ? 60 : 0)
                    }
                    continue
                case .sample(let slot):
                    if let mix = stemMix(deck) {
                        let part = slot % 4
                        reports.lamp(light.lamp, level: mix.muted.contains(part) ? 0 : UInt8(mix.gain[part] * 127))
                    } else {
                        reports.lamp(light.lamp, level: sampleLevel(slot))
                    }
                    continue
                default: active = false
                }
                reports.lamp(light.lamp, level: active ? 127 : 5)
            }
            if session.model == .f1 {
                reports.digits(1, first: 0, count: 2, width: 8, reversed: true)
            }
            if session.model == .z2 {
                for (side, deck) in session.decks.enumerated() {
                    let beats = performance.loopBeats(for: deck)
                    reports.digits(Int((beats < 1 ? 1 / beats : beats).rounded()), first: 52 + 21 * side,
                                   count: 3, width: 7, fraction: beats < 1)
                }
            }
            for (side, pulse) in profile.pulses.enumerated() {
                let state = snapshot[session.decks[side]]
                let frames = playback.core.asset(generation: state.generation)?.frames
                if session.model == .x1MK1 && session.hotcueMode { continue }
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
