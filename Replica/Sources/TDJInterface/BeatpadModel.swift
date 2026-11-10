#if os(iOS)
    import TDJCore

    extension ReplicaModel {
        func startBeatpad() {
            guard beatpadConnection == nil else { return }
            let connection = BeatpadMIDIConnection()
            connection.onMessage = { [weak self] message, time in
                guard let self else { return }
                let mode = message.channel < 2 ? beatpadControls.sides[Int(message.channel)].mode : nil
                for event in beatpadControls.consume(message, time: time) { applyBeatpadEvent(event) }
                if let mode, mode != beatpadControls.sides[Int(message.channel)].mode {
                    beatpadConnection?.invalidateFeedback()
                }
            }
            connection.onReset = { [weak self] in self?.releaseBeatpadControls() }
            beatpadConnection = connection
            connection.start()
        }

        func maintainBeatpad() {
            guard let connection = beatpadConnection else { return }
            if !connection.isConnected { connection.poll() }
            let currentStatus =
                connection.isConnected
                ? (connection.hasFeedback
                    ? "Beatpad controls and lights connected." : "Beatpad controls connected. Lights unavailable.")
                : "Waiting for the original Beatpad."
            if beatpadStatus != currentStatus { beatpadStatus = currentStatus }
            guard connection.hasFeedback, let snapshot = playbackSnapshot else { return }
            var feedback = BeatpadLights.Feedback()
            feedback.lighting = lightOptions(for: "Beatpad")
            feedback.sampleSlots = Set(s2SampleSlots.keys)
            feedback.playingSamples = playback.core.playingPads
            feedback.recording = isRecording
            for deck in DeckID.primary {
                let state = snapshot[deck]
                if state.phase == .playing {
                    feedback.frames[deck] = playback.core.asset(generation: state.generation)?.frames
                }
                if let track = loaded[deck], let cues = performance.cues[track] { feedback.cues[deck] = Set(cues.keys) }
                if beatpadPerformance.cueContacts[deck]?.generation == state.generation {
                    feedback.heldCue.insert(deck)
                }
                if effects[deck]?[selectedEffectSlots[deck, default: 0]]?.enabled == true {
                    feedback.effects.insert(deck)
                }
            }
            connection.feedback(BeatpadLights.report(snapshot: snapshot, controls: beatpadControls, feedback: feedback))
        }

        private func applyBeatpadEvent(_ event: BeatpadEvent) {
            switch event {
            case .shared(.cue(let deck, held: true)):
                pressS4Cue(deck, stateKey: \.beatpadPerformance, recallStored: true)
            case .shared(.native(.move(let deck, let detents, shifted: true))):
                if playbackSnapshot?[deck].loopEnabled == true {
                    moveS3Loop(deck: deck, beats: Double(detents) * performance.loopBeats(for: deck))
                }
            case .shared(let event):
                applyNativeMK2Event(event, stateKey: \.beatpadPerformance)
            case .hotCue(let deck, let slot, let delete):
                cue(slot: slot, deck: deck, delete: delete)
            case .setCue(let deck):
                guard let state = playback.core.snapshot()?[deck], state.generation != 0, !preparingTrack.contains(deck)
                else { return }
                cuePoints[deck] = state.sourceFrame
                beatpadPerformance.cueMarks[deck] = .init(generation: state.generation, frame: state.sourceFrame)
            case .seek(let deck, let beats):
                beatJump(beats: beats, deck: deck)
            case .brake(let deck):
                if playbackSnapshot?[deck].phase.active == true { pressPlay(deck: deck, vinylStop: true) }
            case .reverse(let deck, let held):
                if held { resetControllerWheelJog(deck, restoreRate: false) }
                perform(.rate, deck: deck, value: held ? -1 : 1)
            case .bend(let deck, let direction):
                resetControllerWheelJog(deck, restoreRate: false)
                perform(.rate, deck: deck, value: 1 + 0.04 * Double(direction))
            case .roll(let deck, let beats, let held):
                setNativeTraktorRoll(deck: deck, held: held, quantized: true, beats: beats)
            case .effectSelect(let deck, let delta):
                let slot = selectedEffectSlots[deck, default: 0]
                var effect = effects[deck]?[slot] ?? .init()
                let count = PerformanceEffect.supportedCount
                effect.kind = ((effect.kind + delta) % count + count) % count
                setEffect(effect, slot: slot, deck: deck)
            case .effectWet(let deck, let wet):
                let slot = selectedEffectSlots[deck, default: 0]
                var effect = effects[deck]?[slot] ?? .init()
                effect.y = wet
                setEffect(effect, slot: slot, deck: deck)
            case .instantFX(let deck, let pad, let held):
                if held {
                    let slot = beatpadInstantFX[deck]?.slot ?? selectedEffectSlots[deck, default: 0]
                    let effect = effects[deck]?[slot] ?? .init()
                    if beatpadInstantFX[deck] == nil { beatpadInstantFX[deck] = (slot, effect) }
                    let presets: [PerformanceEffect] = [.delay, .flanger, .gater, .beatmasher]
                    setEffect(
                        .init(kind: presets[pad].rawValue, x: 0.5, y: 0.65, enabled: true), slot: slot, deck: deck)
                } else {
                    restoreBeatpadEffect(deck)
                }
            case .loadStopped:
                if let deck = DeckID.primary.first(where: {
                    !preparingTrack.contains($0) && playbackSnapshot?[$0].phase.active != true
                }) {
                    queueS2Browser(.load(deck))
                }
            case .faderStart(let deck, let value):
                applyController(deck == .a ? .levelA : .levelB, value: value, targetDeck: deck)
                if value > 0, playbackSnapshot?[deck].phase.active != true {
                    pressPlay(deck: deck, vinylStop: false)
                } else if value == 0, playbackSnapshot?[deck].phase.active == true {
                    applyNativeTraktorEvent(.park(deck, atCue: true), isS3: false)
                }
            }
        }

        private func restoreBeatpadEffect(_ deck: DeckID) {
            if let saved = beatpadInstantFX.removeValue(forKey: deck) {
                setEffect(saved.effect, slot: saved.slot, deck: deck)
            }
        }

        private func releaseBeatpadControls() {
            for (side, deck) in DeckID.primary.enumerated() {
                let input = beatpadControls.sides[side]
                if input.scratch {
                    applyTraktorDeckAction(side == 0 ? .jogTouchA : .jogTouchB, deck: deck, value: 0, quantized: false)
                }
                resetControllerWheelJog(deck)
                if input.reverse || input.bend != 0 { perform(.rate, deck: deck, value: 1) }
                if input.roll != nil { setNativeTraktorRoll(deck: deck, held: false, quantized: true) }
                releaseS4PerformanceContacts(deck, stateKey: \.beatpadPerformance)
                restoreBeatpadEffect(deck)
            }
            beatpadControls = .init()
            beatpadPerformance = .init()
        }
    }
#endif
