#if os(iOS)
    import AVFoundation
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
            case .native(.mic):
                toggleS2MK2Mic()
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

        private func toggleS2MK2Mic() {
            if s2MK2MicPending || playback.s2MK2MicEnabled {
                stopS2MK2Mic()
                s2MK2Status = "S2 Mk2 microphone off."
                return
            }
            s2MK2MicPending = true
            if playback.automaticOutputDevice != "S2 Mk2" {
                s2MK2Status = "Waiting for S2 Mk2 audio."
            } else if !playback.canOpenCapture(device: "S2 Mk2") {
                s2MK2Status = "S2 Mk2 microphone will turn on when playback pauses."
            }
            maintainS2MK2Mic()
        }

        func maintainS2MK2Mic() {
            guard s2MK2MicPending, s2MK2MicRequest == nil, s2MK2Connection?.isReceiving == true,
                playback.automaticOutputDevice == "S2 Mk2", playback.canOpenCapture(device: "S2 Mk2")
            else { return }
            s2MK2MicRequest = Task { [weak self] in
                guard let self else { return }
                defer {
                    if !Task.isCancelled { s2MK2MicRequest = nil }
                }
                let granted: Bool
                switch AVAudioApplication.shared.recordPermission {
                case .granted: granted = true
                case .undetermined: granted = await AVAudioApplication.requestRecordPermission()
                default: granted = false
                }
                guard !Task.isCancelled, s2MK2Connection?.isReceiving == true else { return }
                guard granted else {
                    s2MK2MicPending = false
                    s2MK2Status = "Allow microphone access to use S2 Mk2 MIC ENGAGE."
                    return
                }
                guard playback.automaticOutputDevice == "S2 Mk2", playback.canOpenCapture(device: "S2 Mk2") else {
                    return
                }
                s2MK2MicPending = false
                cancelNativeMusicAnalysis()
                do {
                    try playback.setCaptureEnabled(true, device: "S2 Mk2")
                    s2MK2Status = "S2 Mk2 microphone on."
                } catch {
                    s2MK2Status = error.localizedDescription
                }
            }
        }

        private func stopS2MK2Mic() {
            s2MK2MicPending = false
            s2MK2MicRequest?.cancel()
            s2MK2MicRequest = nil
            try? playback.setCaptureEnabled(false, device: "S2 Mk2")
        }

        private func releaseS2MK2Controls() {
            stopS2MK2Mic()
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
            feedback.lighting = lightOptions(for: "S2 Mk2")
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
