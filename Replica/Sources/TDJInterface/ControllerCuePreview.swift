import Foundation
import TDJCore

struct ControllerCueContact {
    let generation: UInt64
    let frame: Double
}

extension ReplicaModel {
    /**
     * Uses the native Cue contact contract without changing the saved Sync choice.
     */
    func pressControllerCue(_ deck: DeckID) {
        guard controllerCueContacts[deck] == nil, !preparingTrack.contains(deck), !editing.contains(deck),
            !frozen.contains(deck), !controllerJogTouched.contains(deck),
            let state = playback.core.snapshot()?[deck], !state.loopRolling, !state.braking, !state.touchActive,
            playback.generations[deck] == state.generation,
            let asset = playback.core.asset(generation: state.generation), asset.frames > 0
        else { return }
        let upper = Double(asset.frames)
        if state.phase.active {
            let frame = min(upper - 1, max(0, cuePoints[deck] ?? 0))
            do {
                try playback.finishCueContact(
                    deck: deck, generation: state.generation, cue: frame, continuePlaying: false)
                refreshPlayback()
            } catch { status = error.localizedDescription }
            return
        }
        let source = min(upper - 1, max(0, state.sourceFrame))
        let saved =
            state.synced ? state.timing?.nearestPhaseAlignedFrame(to: source, masterBeat: 0, within: 0..<upper) : nil
        let cue = ControllerCueContact(generation: state.generation, frame: saved ?? source)
        let phase = playbackSnapshot?.masterBeat ?? 0
        let aligned =
            state.synced
            ? state.timing?.nearestPhaseAlignedFrame(to: cue.frame, masterBeat: phase, within: 0..<upper) : nil
        cancelCloudSyncForPlayback()
        do {
            try playback.perform(.touch, deck: deck, value: aligned ?? cue.frame, touchRate: 1, followsPosition: true)
            controllerCueContacts[deck] = cue
            cuePoints[deck] = cue.frame
            refreshPlayback()
        } catch { status = error.localizedDescription }
    }

    /**
     * Returns true when a current Cue contact consumes the release or Play press.
     */
    @discardableResult func finishControllerCue(_ deck: DeckID, continuePlaying: Bool) -> Bool {
        guard let cue = controllerCueContacts.removeValue(forKey: deck),
            playback.generations[deck] == cue.generation, playback.core.snapshot()?[deck].generation == cue.generation
        else { return false }
        do {
            try playback.finishCueContact(
                deck: deck, generation: cue.generation, cue: cue.frame, continuePlaying: continuePlaying)
            refreshPlayback()
        } catch {
            if continuePlaying {
                try? playback.finishCueContact(
                    deck: deck, generation: cue.generation, cue: cue.frame, continuePlaying: false)
            }
            status = error.localizedDescription
            refreshPlayback()
        }
        return true
    }
}
