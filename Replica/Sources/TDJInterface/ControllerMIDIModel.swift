import Foundation
import TDJCore

extension ReplicaModel {
    func configureControllerMIDI() {
        controllerInput.onJogAction = { [weak self] target, motion in self?.applyControllerJog(target, motion: motion) }
        controllerInput.onTargetAction = { [weak self] target, value in
            self?.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
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

    func applyControllerJog(_ target: ControllerActionTarget, motion: ControllerMIDIValue) {
        let deck = target.deck ?? target.action.deck
        guard target.action.isJog else { return }
        if [.wheelJogA, .wheelJogB].contains(target.action), controllerJogTouched.contains(deck) { return }
        switch motion {
        case .absolute(let value):
            resetControllerCountJog(deck, stop: false)
            applyController(target.action, value: value, targetDeck: deck)
        case .relative(let counts):
            guard counts.isFinite, counts != 0, let track = track(deck), let state = playbackSnapshot?[deck] else {
                return
            }
            let resolution = target.argument ?? ControllerCountJogMotion.defaultResolution
            guard ControllerCountJogMotion.validResolution(resolution) else { return }
            if controllerJogTouched.contains(deck) {
                controllerPausedJogs[deck] = nil
                let now = ProcessInfo.processInfo.systemUptime
                var motion = controllerCountJogs[deck]
                if motion?.generation != state.generation {
                    motion = .init(
                        frame: state.sourceFrame, generation: state.generation, sampleRate: track.analysis.sampleRate,
                        limit: max(0, Double(track.analysis.frameCount) - 1), resolution: resolution, time: now)
                }
                guard var motion else { return }
                motion.move(counts: counts * motion.resolution / resolution, time: now)
                controllerCountJogs[deck] = motion
                applyControllerCountJog(motion, deck: deck, stopped: false)
                controllerCountJogTasks[deck]?.cancel()
                let token = UUID()
                controllerCountJogTokens[deck] = token
                controllerCountJogTasks[deck] = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: ControllerCountJogMotion.idleNanoseconds) } catch { return }
                    guard let self, self.controllerCountJogTokens[deck] == token,
                        self.controllerJogTouched.contains(deck), let motion = self.controllerCountJogs[deck],
                        self.playbackSnapshot?[deck].generation == motion.generation
                    else { return }
                    self.applyControllerCountJog(motion, deck: deck, stopped: true)
                }
            } else if !state.phase.active, !state.touchActive {
                let delta = counts * track.analysis.sampleRate * 1.8 / resolution
                guard delta.isFinite else { return }
                guard !preparingPlayback.contains(deck) else { return }
                let previous = controllerPausedJogs[deck]
                let frame: Double
                if let previous, previous.generation == state.generation, previous.resolution == resolution {
                    frame = previous.frame
                } else {
                    frame = state.sourceFrame
                }
                let position = boundedFrame(frame + delta, deck: deck)
                jump(position, deck: deck, quantized: false)
                controllerPausedJogs[deck] = (state.generation, resolution, position)
            } else {
                applyControllerWheelJog(0.5 + min(4, max(-4, counts)) / 8, deck: deck)
            }
        }
    }

    private func applyControllerCountJog(_ motion: ControllerCountJogMotion, deck: DeckID, stopped: Bool) {
        guard let track = track(deck), playbackSnapshot?[deck].generation == motion.generation else { return }
        let speed = playbackSnapshot?[deck].speed ?? 1
        let rate = stopped ? 0 : min(4, max(-4, motion.velocity / (track.analysis.sampleRate * max(0.001, speed))))
        performControllerJogTouch(deck, frame: motion.frame, touchRate: rate, followsPosition: true)
    }

    /**
     * Retires hardware ownership after a later touch command succeeds.
     */
    func relinquishControllerJogForTouch(_ deck: DeckID) {
        guard controllerJogTouchCommandDeck != deck else { return }
        controllerJogTouched.remove(deck)
        resetControllerCountJog(deck, stop: false)
    }

    /**
     * Marks synchronous hardware touch commands without changing the public touch contract.
     */
    private func performControllerJogTouch(
        _ deck: DeckID, frame: Double = 0, enabled: Bool = true, touchRate: Double? = nil,
        followsPosition: Bool = false
    ) {
        let previous = controllerJogTouchCommandDeck
        controllerJogTouchCommandDeck = deck
        defer { controllerJogTouchCommandDeck = previous }
        perform(
            .touch, deck: deck, value: frame, enabled: enabled, touchRate: touchRate, followsPosition: followsPosition)
    }

    private func resetControllerCountJog(_ deck: DeckID, stop: Bool) {
        controllerPausedJogs[deck] = nil
        controllerCountJogTasks[deck]?.cancel()
        controllerCountJogTasks[deck] = nil
        controllerCountJogTokens[deck] = nil
        if stop, let motion = controllerCountJogs[deck], controllerJogTouched.contains(deck) {
            applyControllerCountJog(motion, deck: deck, stopped: true)
        }
        controllerCountJogs[deck] = nil
    }

    func applyControllerWheelJog(_ value: Double, deck: DeckID) {
        controllerPausedJogs[deck] = nil
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
        case .pitchBendDownA, .pitchBendDownB, .pitchBendUpA, .pitchBendUpB:
            return controllerPitchBendButtons[deck]?.isPressed(
                action == .pitchBendUpA || action == .pitchBendUpB ? .up : .down,
                generation: snapshot[deck].generation) == true ? 1 : 0
        case .cueA, .cueB, .cueStateA, .cueStateB: return mixer.cue ? 1 : 0
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
        _ action: ControllerAction, value: Double, refreshMixer: Bool = true, targetDeck: DeckID? = nil,
        argument: Double? = nil
    ) {
        guard value.isFinite, (0...1).contains(value) else { return }
        let deck = targetDeck ?? action.deck
        func mix(_ parameter: MixerParameter, value: Double, deck: DeckID = .a) {
            if submitMixer(parameter, value: value, deck: deck), refreshMixer { refreshPlayback() }
        }
        switch action {
        case .playA, .playB:
            if !finishControllerCue(deck, continuePlaying: true) { pressPlay(deck: deck) }
        case .syncA, .syncB: toggleSync(deck: deck)
        case .keylockA, .keylockB: toggleKeylock(deck: deck)
        case .cueA, .cueB: mix(.cue, value: playbackSnapshot?[deck].mixer.cue == true ? 0 : 1, deck: deck)
        case .cueStateA, .cueStateB: mix(.cue, value: value > 0 ? 1 : 0, deck: deck)
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
        case .pitchBendDownA, .pitchBendDownB, .pitchBendUpA, .pitchBendUpB:
            applyControllerPitchBend(
                action == .pitchBendUpA || action == .pitchBendUpB ? .up : .down,
                pressed: value > 0, deck: deck)
        case .tempoA, .tempoB: setDeckTempo(percent: value * 16 - 8, deck: deck)
        case .tempoResetA, .tempoResetB: setDeckTempo(percent: 0, deck: deck)
        case .seekA, .seekB:
            if let track = track(deck) { jump(value * max(0, Double(track.analysis.frameCount) - 1), deck: deck) }
        case .fixedJumpA, .fixedJumpB:
            if let argument, argument.isFinite, abs(argument) <= 64 { beatJump(beats: argument, deck: deck) }
        case .toggleFixedLoopA, .toggleFixedLoopB:
            guard let argument, PerformancePreparation.loopSizes.contains(argument) else { return }
            guard let state = playbackSnapshot?[deck], let grid = timing(deck) else {
                setLoopSize(argument, deck: deck)
                return
            }
            let requestedSpan = grid.span(beats: argument, from: state.loopStart)
            if state.loopEnabled && abs(state.loopEnd - state.loopStart - requestedSpan) <= 1 {
                toggleLoop(deck: deck)
            } else {
                setLoopSize(argument, deck: deck)
                if !state.loopEnabled { toggleLoop(deck: deck) }
            }
        case .fixedLoopA, .fixedLoopB:
            if let argument, PerformancePreparation.loopSizes.contains(argument) {
                setLoopSize(argument, deck: deck)
                if playbackSnapshot?[deck].loopEnabled != true { toggleLoop(deck: deck) }
            }
        case .loopInOrHalveA, .loopInOrHalveB, .loopOutOrDoubleA, .loopOutOrDoubleB:
            let isIn = action == .loopInOrHalveA || action == .loopInOrHalveB
            guard let state = playbackSnapshot?[deck] else { return }
            if state.loopEnabled {
                let span = state.loopEnd - state.loopStart
                guard span > 0 else { return }
                setLoop(start: state.loopStart, end: state.loopStart + span * (isIn ? 0.5 : 2), deck: deck)
            } else {
                applyController(isIn ? .loopInA : .loopOutA, value: value, targetDeck: deck)
            }
        case .loopInA, .loopInB:
            if let state = playbackSnapshot?[deck], state.generation != 0 {
                controllerLoopStarts[deck] = (state.generation, snappedFrame(state.sourceFrame, deck: deck))
            }
        case .loopOutOrExitA, .loopOutOrExitB:
            if playbackSnapshot?[deck].loopEnabled == true {
                toggleLoop(deck: deck)
            } else {
                applyController(.loopOutA, value: value, targetDeck: deck)
            }
        case .loopOutA, .loopOutB:
            if let state = playbackSnapshot?[deck], let start = controllerLoopStarts[deck],
                state.generation == start.generation
            {
                let end = snappedFrame(state.sourceFrame, deck: deck)
                if end > start.frame { setLoop(start: start.frame, end: end, deck: deck) }
            }
        case .reloopA, .reloopB, .reloopOriginalA, .reloopOriginalB:
            if let state = playbackSnapshot?[deck] {
                if state.loopEnabled {
                    perform(.loop, deck: deck, enabled: false)
                } else if state.loopEnd > state.loopStart {
                    var division = controllerLoopDivisions[deck, default: .init()]
                    let original =
                        action == .reloopOriginalA || action == .reloopOriginalB
                        ? division.restore(generation: state.generation, start: state.loopStart, end: state.loopEnd)
                        : nil
                    controllerLoopDivisions[deck] = division
                    setLoop(start: state.loopStart, end: original ?? state.loopEnd, deck: deck)
                }
            }
        case .loopEnableA, .loopEnableB:
            guard let state = playbackSnapshot?[deck], !state.loopEnabled else { return }
            toggleLoop(deck: deck)
        case .loopA, .loopB:
            if let argument {
                guard PerformancePreparation.loopSizes.contains(argument) else { return }
                setLoopSize(argument, deck: deck)
            }
            toggleLoop(deck: deck)
        case .loopDivideA, .loopDivideB, .loopRestoreA, .loopRestoreB:
            guard let state = playbackSnapshot?[deck] else { return }
            guard state.loopEnabled else {
                controllerLoopDivisions[deck] = nil
                toggleLoop(deck: deck)
                return
            }
            var division = controllerLoopDivisions[deck, default: .init()]
            let end =
                action == .loopDivideA || action == .loopDivideB
                ? division.divide(generation: state.generation, start: state.loopStart, end: state.loopEnd)
                : division.restore(generation: state.generation, start: state.loopStart, end: state.loopEnd)
            controllerLoopDivisions[deck] = division
            if let end { setLoop(start: state.loopStart, end: end, deck: deck) }
        case .loopSizeA, .loopSizeB:
            let steps = Int(((value - 0.5) * 126).rounded())
            let sizes = PerformancePreparation.loopSizes
            let current = performance.loopBeats(for: deck)
            let index = sizes.firstIndex(of: current) ?? sizes.firstIndex(of: 4)!
            let next = sizes[min(sizes.count - 1, max(0, index + steps))]
            if steps != 0 && next != current { setLoopSize(next, deck: deck) }
        case .loopUpA, .loopUpB: stepLoopSize(direction: 1, deck: deck)
        case .loopDownA, .loopDownB: stepLoopSize(direction: -1, deck: deck)
        case .jumpBackA, .jumpBackB: beatJump(beats: -performance.loopBeats(for: deck), deck: deck)
        case .jumpForwardA, .jumpForwardB: beatJump(beats: performance.loopBeats(for: deck), deck: deck)
        case .cueReturnA, .cueReturnB: pressCue(deck: deck)
        case .cueSetA, .cueSetB:
            refreshPlayback()
            if loaded[deck] != nil, let state = playbackSnapshot?[deck], state.generation != 0 {
                cuePoints[deck] = state.sourceFrame
            }
        case .cueGotoA, .cueGotoB:
            if let frame = cuePoints[deck] { jump(frame, deck: deck, quantized: false) }
        case .cuePreviewA, .cuePreviewB:
            if value > 0 { pressControllerCue(deck) } else { finishControllerCue(deck, continuePlaying: false) }
        case .freezeA, .freezeB: toggleFreeze(deck: deck)
        case .jogTouchA, .jogTouchB:
            guard value > 0 || controllerJogTouched.contains(deck) else { return }
            resetControllerCountJog(deck, stop: value == 0)
            if value > 0 {
                finishControllerCue(deck, continuePlaying: false)
                resetControllerWheelJog(deck, restoreRate: false)
                controllerJogTouched.insert(deck)
                guard let frame = playbackSnapshot?[deck].sourceFrame else { return }
                performControllerJogTouch(deck, frame: frame, touchRate: 0)
            } else {
                controllerJogTouched.remove(deck)
                performControllerJogTouch(deck, enabled: false)
            }
        case .jogA, .jogB:
            let rate = min(4, max(-4, (value - 0.5) * 8))
            guard controllerJogTouched.contains(deck) else {
                applyControllerWheelJog(value, deck: deck)
                return
            }
            guard let frame = playbackSnapshot?[deck].sourceFrame else { return }
            performControllerJogTouch(deck, frame: frame, touchRate: rate)
        case .wheelJogA, .wheelJogB: applyControllerWheelJog(value, deck: deck)
        case .browsePrevious, .browseNext, .browsePreviousGroup, .browseNextGroup:
            #if os(iOS)
                if let step = action.browserStep { queueS2Browser(.move(step.detents, groups: step.groups)) }
            #endif
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
