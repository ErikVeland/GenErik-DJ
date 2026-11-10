#if os(iOS)
    import Foundation
    import TDJCore

    extension ReplicaModel {
        func startS2MK2() {
            guard s2MK2Connection == nil else { return }
            let connection = NIControllerAccessoryConnection(model: .s2MK2)
            connection.onState = { [weak self] status, _ in self?.s2MK2Status = status }
            connection.onFrame = { [weak self] frame in
                guard let self else { return }
                if frame.reportID == 1 {
                    for event in s2MK2Controls.consume(frame.payload) { applyS2MK2Event(event) }
                } else {
                    s2MK2Controls.addCalibration(frame)
                }
            }
            connection.onDisconnect = { [weak self] in self?.releaseS2MK2Controls() }
            s2MK2Connection = connection
            do { try connection.start() } catch { s2MK2Status = error.localizedDescription }
        }

        private func applyS2MK2Event(_ event: S4MK2Event) {
            switch event {
            case .pad(let deck, let slot, let held, let shifted)
            where s2MK2Controls.samples.contains(deck) && s2MK2Performance.slices[deck] == nil:
                if held { pressS2Sample(slot: S2MK3Controls.sampleSlot(deck: deck, pad: slot), shifted: shifted) }
            case .native(.move(let deck, let detents, let shifted)):
                if s2MK2Controls.gridEditing.contains(deck) {
                    beatJump(beats: Double(detents) * 4, deck: deck)
                } else if shifted, s2MK2Performance.slices[deck] == nil {
                    guard let duration = track(deck)?.analysis.duration, duration > 0 else { return }
                    let seconds = waveformZoomSeconds(deck: deck) * pow(2, Double(detents))
                    setWaveformZoomSeconds(
                        max(min(1, duration), min(duration, seconds)), deck: deck, loadID: loadIdentity(deck))
                } else {
                    applyNativeMK2Event(event, stateKey: \.s2MK2Performance)
                }
            default:
                applyNativeMK2Event(event, stateKey: \.s2MK2Performance)
            }
        }

        private func releaseS2MK2Controls() {
            for deck in s2MK2Controls.touched {
                applyTraktorDeckAction(deck.leftSide ? .jogTouchA : .jogTouchB, deck: deck, value: 0, quantized: false)
            }
            for deck in DeckID.primary { releaseS4PerformanceContacts(deck, stateKey: \.s2MK2Performance) }
            for deck in s2MK2Controls.bent { resetControllerWheelJog(deck) }
            for deck in s2MK2Controls.gridEditing { endS2Grid(deck: deck, save: false) }
            if s2Connection?.isReceiving != true, s3Connection?.isReceiving != true, s4Connection?.isReceiving != true {
                s2SampleLoad?.cancel()
                for (slot, generation) in s2SampleSlots {
                    try? playback.triggerPad(slot, generation: generation, enabled: false)
                }
                s2BrowserCommands.removeAll()
            }
            for (deck, effects) in s2MK2Performance.previousFX {
                for (slot, effect) in effects.enumerated() { setEffect(effect, slot: slot, deck: deck) }
            }
            s2MK2Controls = .init()
            s2MK2Performance = .init(sliceCount: 4)
        }

        func refreshS2MK2Lights() {
            guard let connection = s2MK2Connection, connection.isReceiving, let snapshot = playbackSnapshot else {
                return
            }
            var feedback = S4MK2Lights.Feedback()
            var cueKinds: [DeckID: [Int: PerformanceCueKind]] = [:]
            feedback.samples = playback.core.playingPads
            feedback.sampleSlots = Set(s2SampleSlots.keys)
            feedback.fxDecks = s2MK2Performance.fx.map(\.decks)
            feedback.fxActive = s2MK2Performance.fx.map(\.enabled)
            feedback.fxSlots = s2MK2Performance.fx.map(\.slots)
            for deck in DeckID.primary {
                let state = snapshot[deck]
                if let contact = s2MK2Performance.slices[deck] {
                    if contact.generation != state.generation || (contact.bank.looping && !state.loopEnabled) {
                        endS4SliceMode(deck, stateKey: \.s2MK2Performance)
                    } else {
                        feedback.sliceModes[deck] = contact.bank.looping
                        feedback.heldSlices[deck] = contact.held.last
                    }
                }
                feedback.cueHeld[deck] = s2MK2Performance.cueContacts[deck]?.generation == state.generation
                feedback.frames[deck] = playback.core.asset(generation: state.generation)?.frames
                if let track = loaded[deck], let cues = performance.cues[track] {
                    cueKinds[deck] = cues.mapValues(\.category)
                }
                feedback.loopMarked[deck] = s2MK2Performance.loopIn[deck]?.generation == state.generation
            }
            connection.send(
                S2MK2Lights.report(snapshot: snapshot, controls: s2MK2Controls, feedback: feedback, cueKinds: cueKinds))
        }
    }
#endif
