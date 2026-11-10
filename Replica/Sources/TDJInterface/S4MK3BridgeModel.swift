#if os(iOS)
    import TDJCore

    extension ReplicaModel {
        func startS4MK3Bridge() {
            guard s4MK3Bridge == nil else { return }
            let bridge = S4MK3BridgeConnection()
            bridge.onReport = { [weak self] report in
                guard let self else { return }
                for event in s4MK3Controls.consume(report) { applyS4MK3Event(event) }
            }
            bridge.onDisconnect = { [weak self] in self?.releaseS4MK3Bridge() }
            s4MK3Bridge = bridge
            bridge.start()
        }

        private func applyS4MK3Event(_ event: S4MK2Event) {
            switch event {
            case .native(.s3Preview(let held)):
                if held {
                    guard automaticOutputDevice == "S4 Mk3 Bridge" else { return }
                    s4MK3Performance.ownsPreview = true
                } else {
                    guard s4MK3Performance.ownsPreview else { return }
                    s4MK3Performance.ownsPreview = false
                }
                applyNativeTraktorEvent(.s3Preview(held), isS3: false)
            case .native(.s3PreviewSeek(let detents)):
                if s4MK3Performance.ownsPreview { seekS3Preview(detents: detents) }
            case .pad(let deck, let slot, let held, let shifted) where s4MK3Performance.slices[deck] == nil:
                guard held, s4MK3Performance.cueContacts[deck] == nil else { return }
                let adding = loaded[deck].map { performance.cues[$0]?[slot] == nil } ?? false
                cue(
                    slot: slot, deck: deck, delete: shifted,
                    quantized: adding ? s4MK3Performance.snap : s4MK3Performance.quantize)
            case .native(.gridBegin(let deck, _)):
                releaseS4PerformanceContacts(deck, stateKey: \.s4MK3Performance)
                applyNativeMK2Event(event, stateKey: \.s4MK3Performance)
            default:
                applyNativeMK2Event(event, stateKey: \.s4MK3Performance)
            }
        }

        private func releaseS4MK3Bridge() {
            s4MK3BridgeStatus = "Waiting for S4 Mk3 bridge."
            if s4MK3Performance.ownsPreview { stopS3Preview() }
            for deck in s4MK3Controls.touched {
                applyTraktorDeckAction(deck.leftSide ? .jogTouchA : .jogTouchB, deck: deck, value: 0, quantized: false)
            }
            for deck in DeckID.allCases { releaseS4PerformanceContacts(deck, stateKey: \.s4MK3Performance) }
            for deck in s4MK3Controls.bent { resetControllerWheelJog(deck) }
            for deck in s4MK3Controls.reversing { perform(.rate, deck: deck, value: 1) }
            for deck in s4MK3Controls.gridHeld { endS2Grid(deck: deck, save: false) }
            for (deck, effects) in s4MK3Performance.previousFX {
                for (slot, effect) in effects.enumerated() { setEffect(effect, slot: slot, deck: deck) }
            }
            if s2Connection?.isReceiving != true, s2MK2Connection?.isReceiving != true,
                s3Connection?.isReceiving != true, s4Connection?.isReceiving != true
            {
                s2SampleLoad?.cancel()
                for (slot, generation) in s2SampleSlots {
                    try? playback.triggerPad(slot, generation: generation, enabled: false)
                }
                s2BrowserCommands.removeAll()
            }
            s4MK3Controls = .init()
            s4MK3Performance = .init()
        }

        func maintainS4MK3Bridge() {
            guard let bridge = s4MK3Bridge else { return }
            bridge.poll()
            guard bridge.isReceiving, let snapshot = playbackSnapshot else { return }
            if s4MK3BridgeStatus != "S4 Mk3 bridge controls connected." {
                s4MK3BridgeStatus = "S4 Mk3 bridge controls connected."
            }
            var feedback = S4MK2Lights.Feedback()
            feedback.quantize = s4MK3Performance.quantize
            feedback.preview = s4MK3Performance.ownsPreview && s3PreviewHeld && playback.core.previewGeneration != 0
            feedback.samples = playback.core.playingPads
            feedback.sampleSlots = Set(s2SampleSlots.keys)
            feedback.fxDecks = s4MK3Performance.fx.map(\.decks)
            feedback.fxActive = s4MK3Performance.fx.map(\.enabled)
            feedback.fxSlots = s4MK3Performance.fx.map(\.slots)
            for (side, deck) in s4MK3Controls.layers.enumerated() {
                let state = snapshot[deck]
                if let contact = s4MK3Performance.slices[deck] {
                    if contact.generation != state.generation || (contact.bank.looping && !state.loopEnabled) {
                        endS4SliceMode(deck, stateKey: \.s4MK3Performance)
                    } else {
                        feedback.sliceModes[deck] = contact.bank.looping
                        feedback.heldSlices[deck] = contact.held.last
                    }
                }
                feedback.cueHeld[deck] = s4MK3Performance.cueContacts[deck]?.generation == state.generation
                if let track = loaded[deck], let cues = performance.cues[track] {
                    feedback.cues[deck] = Set(cues.keys)
                }
                bridge.feedback(
                    S4MK3Lights.ring(
                        side: side, state: state,
                        frames: playback.core.asset(generation: state.generation)?.frames))
            }
            bridge.feedback(S4MK3Lights.panel(snapshot: snapshot, controls: s4MK3Controls, feedback: feedback))
        }
    }
#endif
