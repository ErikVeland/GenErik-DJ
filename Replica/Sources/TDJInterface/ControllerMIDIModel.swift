import Foundation
import TDJCore

extension ReplicaModel {
    func configureControllerMIDI() {
        controllerInput.onTargetAction = { [weak self] target, value in
            self?.applyController(target.action, value: value, targetDeck: target.deck)
        }
        controllerInput.currentTargetValue = { [weak self] target in
            self?.controllerValue(target.action, targetDeck: target.deck)
        }
        controllerInput.onAction = { [weak self] action, value in self?.applyController(action, value: value) }
        controllerInput.currentValue = { [weak self] action in self?.controllerValue(action) }
        controllerInput.onZ1Report = { [weak self] report in self?.receiveZ1(report) }
        controllerInput.onZ1Calibration = { [weak self] calibration in self?.configureZ1Bridge(calibration) }
        controllerInput.onBridgeReset = { [weak self] in self?.configureZ1Bridge(nil) }
    }

    func applyControllerWheelJog(_ value: Double, deck: DeckID) {
        guard loaded[deck] != nil else {
            resetControllerWheelJog(deck, restoreRate: false)
            return
        }
        guard playbackSnapshot?[deck].touchActive != true, !controllerJogTouched.contains(deck) else {
            resetControllerWheelJog(deck, restoreRate: false)
            return
        }
        let delta = ControllerJogBend.deltaCounts(fromNormalizedValue: value)
        guard delta != 0 else {
            resetControllerWheelJog(deck)
            return
        }
        let offset = ControllerJogBend.accumulatedCounts(
            current: controllerJogBendOffsets[deck, default: 0], delta: delta)
        controllerJogBendOffsets[deck] = offset
        perform(.rate, deck: deck, value: ControllerJogBend.playbackRate(forCounts: offset))
        controllerJogBendTasks[deck]?.cancel()
        let token = UUID()
        controllerJogBendTokens[deck] = token
        controllerJogBendTasks[deck] = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: ControllerJogBend.releaseDelayNanoseconds) } catch { return }
            guard let self, self.controllerJogBendTokens[deck] == token else { return }
            self.resetControllerWheelJog(deck)
        }
    }

    func resetControllerWheelJog(_ deck: DeckID, restoreRate: Bool = true) {
        let wasActive = controllerJogBendOffsets[deck, default: 0] != 0 || controllerJogBendTasks[deck] != nil
        controllerJogBendTasks[deck]?.cancel()
        controllerJogBendTasks[deck] = nil
        controllerJogBendTokens[deck] = nil
        controllerJogBendOffsets[deck] = 0
        if wasActive, restoreRate, playbackSnapshot?[deck].touchActive != true { perform(.rate, deck: deck, value: 1) }
    }

    func controllerValue(_ action: ControllerAction, targetDeck: DeckID? = nil) -> Double? {
        let deck = targetDeck ?? action.deck
        if let slot = action.hotcueSlot {
            guard let trackID = loaded[deck] else { return 0 }
            return performance.cues[trackID]?[slot] == nil ? 0 : 1
        }
        guard let snapshot = playbackSnapshot else { return nil }
        let mixer = snapshot[deck].mixer
        switch action {
        case .playA, .playB: return snapshot[deck].phase == .playing ? 1 : 0
        case .syncA, .syncB: return snapshot[deck].synced ? 1 : 0
        case .keylockA, .keylockB: return snapshot[deck].keylock ? 1 : 0
        case .cueA, .cueB: return mixer.cue ? 1 : 0
        case .filterToggleA, .filterToggleB: return mixer.filterEnabled ? 1 : 0
        case .loopA, .loopB: return snapshot[deck].loopEnabled ? 1 : 0
        case .fxToggleA, .fxToggleB:
            return effects[deck]?[selectedEffectSlots[deck, default: 0]]?.enabled == true ? 1 : 0
        case .levelA, .levelB: return mixerFaderValue(.volume, deck: deck)
        case .gainA, .gainB: return mixer.gain > 0 ? (log(mixer.gain) / log(4) + 1) / 2 : 0
        case .lowA, .lowB: return mixerFaderValue(.low, deck: deck).map { $0 / 2 }
        case .midA, .midB: return mixerFaderValue(.mid, deck: deck).map { $0 / 2 }
        case .highA, .highB: return mixerFaderValue(.high, deck: deck).map { $0 / 2 }
        case .filterA, .filterB, .filterKnobA, .filterKnobB: return (mixer.filterX + 1) / 2
        case .fxA, .fxB: return effects[deck]?[selectedEffectSlots[deck, default: 0]]?.x ?? 0.5
        case .crossfader: return snapshot.crossfader
        case .cueMix: return snapshot.cueBlend
        case .master: return snapshot.masterGain
        case .monitor: return snapshot.monitorGain
        case .tempoA, .tempoB: return min(1, max(0, (deckTempoPercent(deck: deck) + 8) / 16))
        default: return nil
        }
    }
    func applyController(
        _ action: ControllerAction, value: Double, refreshMixer: Bool = true, targetDeck: DeckID? = nil
    ) {
        guard value.isFinite, (0...1).contains(value) else { return }
        let deck = targetDeck ?? action.deck
        func mix(_ parameter: MixerParameter, value: Double, deck: DeckID = .a) {
            if submitMixer(parameter, value: value, deck: deck), refreshMixer { refreshPlayback() }
        }
        switch action {
        case .playA, .playB: pressPlay(deck: deck)
        case .syncA, .syncB: toggleSync(deck: deck)
        case .keylockA, .keylockB: toggleKeylock(deck: deck)
        case .cueA, .cueB: mix(.cue, value: playbackSnapshot?[deck].mixer.cue == true ? 0 : 1, deck: deck)
        case .levelA, .levelB: mix(.volume, value: value, deck: deck)
        case .gainA, .gainB: mix(.gain, value: pow(4, 2 * value - 1), deck: deck)
        case .lowA, .lowB: mix(.low, value: 2 * value, deck: deck)
        case .midA, .midB: mix(.mid, value: 2 * value, deck: deck)
        case .highA, .highB: mix(.high, value: 2 * value, deck: deck)
        case .filterA, .filterB: mix(.filterX, value: 2 * value - 1, deck: deck)
        case .filterKnobA, .filterKnobB:
            let position = submitMixer(.filterX, value: 2 * value - 1, deck: deck)
            let enabled = submitMixer(.filterEnabled, value: abs(value - 0.5) > 0.005 ? 1 : 0, deck: deck)
            if refreshMixer && (position || enabled) { refreshPlayback() }
        case .filterToggleA, .filterToggleB:
            mix(.filterEnabled, value: playbackSnapshot?[deck].mixer.filterEnabled == true ? 0 : 1, deck: deck)
        case .fxA, .fxB: setHardwareEffectX(value, deck: deck)
        case .fxToggleA, .fxToggleB: toggleHardwareEffect(deck: deck)
        case .crossfader: mix(.crossfader, value: value)
        case .cueMix: mix(.cueBlend, value: value)
        case .master: mix(.master, value: value)
        case .monitor: mix(.monitor, value: value)
        case .tempoA, .tempoB: setDeckTempo(percent: value * 16 - 8, deck: deck)
        case .loopA, .loopB: toggleLoop(deck: deck)
        case .loopUpA, .loopUpB: stepLoopSize(direction: 1, deck: deck)
        case .loopDownA, .loopDownB: stepLoopSize(direction: -1, deck: deck)
        case .jumpBackA, .jumpBackB: beatJump(beats: -performance.loopBeats(for: deck), deck: deck)
        case .jumpForwardA, .jumpForwardB: beatJump(beats: performance.loopBeats(for: deck), deck: deck)
        case .cueReturnA, .cueReturnB: pressCue(deck: deck)
        case .freezeA, .freezeB: toggleFreeze(deck: deck)
        case .jogTouchA, .jogTouchB:
            if value > 0 {
                resetControllerWheelJog(deck, restoreRate: false)
                controllerJogTouched.insert(deck)
                guard let frame = playbackSnapshot?[deck].sourceFrame else { return }
                perform(.touch, deck: deck, value: frame, touchRate: 0)
            } else {
                controllerJogTouched.remove(deck)
                perform(.touch, deck: deck, enabled: false)
            }
        case .jogA, .jogB:
            let rate = min(4, max(-4, (value - 0.5) * 8))
            guard controllerJogTouched.contains(deck) else {
                applyControllerWheelJog(value, deck: deck)
                return
            }
            guard let frame = playbackSnapshot?[deck].sourceFrame else { return }
            perform(.touch, deck: deck, value: frame, touchRate: rate)
        case .wheelJogA, .wheelJogB: applyControllerWheelJog(value, deck: deck)
        case .browse, .browseGroups:
            #if os(iOS)
                let detents = Int(((value - 0.5) * 126).rounded())
                if detents != 0 { queueS2Browser(.move(detents, groups: action == .browseGroups)) }
            #endif
        case .openGroup:
            #if os(iOS)
                queueS2Browser(.openGroup)
            #endif
        case .loadA, .loadB:
            #if os(iOS)
                queueS2Browser(.load(deck))
            #endif
        case .hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A, .hotcue1B,
            .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B:
            if let slot = action.hotcueSlot { cue(slot: slot, deck: deck) }
        case .shift: break
        }
    }
}
