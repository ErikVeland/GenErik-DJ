import Observation
import TDJCore

// Stable control values are separate from the continuously advancing playback clock.
@MainActor @Observable final class MixerControlDisplay {
    private(set) var volume: Double = 1
    private(set) var low: Double = 1
    private(set) var mid: Double = 1
    private(set) var high: Double = 1
    private(set) var cue: Bool = false
    private(set) var filterX: Double = 0
    private(set) var filterY: Double = 0
    private(set) var filterEnabled: Bool = false
    func update(_ state: DeckMixerSnapshot?) {
        if volume != (state?.volume ?? 1) { volume = state?.volume ?? 1 }
        if low != (state?.low ?? 1) { low = state?.low ?? 1 }
        if mid != (state?.mid ?? 1) { mid = state?.mid ?? 1 }
        if high != (state?.high ?? 1) { high = state?.high ?? 1 }
        if cue != (state?.cue ?? false) { cue = state?.cue ?? false }
        if filterX != (state?.filterX ?? 0) { filterX = state?.filterX ?? 0 }
        if filterY != (state?.filterY ?? 0) { filterY = state?.filterY ?? 0 }
        if filterEnabled != (state?.filterEnabled ?? false) { filterEnabled = state?.filterEnabled ?? false }
    }
}

@MainActor @Observable final class DeckControlDisplay {
    private(set) var phase: PlaybackPhase = .empty
    private(set) var synced: Bool = false
    private(set) var keylock: Bool = false
    private(set) var speed: Double = 1
    private(set) var loopEnabled: Bool = false
    private(set) var fluxEnabled: Bool = false
    private(set) var needsAlignment = false
    let mixer = MixerControlDisplay()
    func update(_ state: DeckPlaybackSnapshot?, needsAlignment: Bool) {
        if phase != (state?.phase ?? .empty) { phase = state?.phase ?? .empty }
        if synced != (state?.synced ?? false) { synced = state?.synced ?? false }
        if keylock != (state?.keylock ?? false) { keylock = state?.keylock ?? false }
        if speed != (state?.speed ?? 1) { speed = state?.speed ?? 1 }
        if loopEnabled != (state?.loopEnabled ?? false) { loopEnabled = state?.loopEnabled ?? false }
        if fluxEnabled != (state?.fluxEnabled ?? false) { fluxEnabled = state?.fluxEnabled ?? false }
        if self.needsAlignment != needsAlignment { self.needsAlignment = needsAlignment }
        mixer.update(state?.mixer)
    }
}

@MainActor @Observable final class PlaybackControlDisplay {
    private(set) var masterBPM = 120.0
    private(set) var crossfader = 0.5
    private let a = DeckControlDisplay()
    private let b = DeckControlDisplay()
    subscript(_ deck: DeckID) -> DeckControlDisplay { deck == .a ? a : b }
    func update(_ state: PlaybackSnapshot?) {
        if masterBPM != (state?.masterBPM ?? 120) { masterBPM = state?.masterBPM ?? 120 }
        if crossfader != (state?.crossfader ?? 0.5) { crossfader = state?.crossfader ?? 0.5 }
        a.update(state?.a, needsAlignment: state?.syncNeedsAlignment(.a) == true)
        b.update(state?.b, needsAlignment: state?.syncNeedsAlignment(.b) == true)
    }
}
