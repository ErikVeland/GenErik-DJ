#if os(iOS)
    import TDJCore

    extension ReplicaModel {
        func startS4MK1Bridge() {
            guard s4MK1Bridge == nil else { return }
            let bridge = TraktorHIDBridgeConnection(.s4MK1)
            bridge.onReport = { [weak self] report in
                guard let self else { return }
                for event in s4MK1Controls.consume(report) { applyS4MK1Event(event) }
            }
            bridge.onDisconnect = { [weak self] in self?.releaseS4MK1Bridge() }
            s4MK1Bridge = bridge
            bridge.start()
        }

        private func applyS4MK1Event(_ event: S4MK2Event) {
            switch event {
            case .pad(let deck, let slot, let held, let shifted):
                guard held, s4MK1Performance.cueContacts[deck] == nil else { return }
                let adding = loaded[deck].map { performance.cues[$0]?[slot] == nil } ?? false
                cue(
                    slot: slot, deck: deck, delete: shifted,
                    quantized: adding ? s4MK1Performance.snap : s4MK1Performance.quantize)
            case .native(.move(let deck, let detents, let shifted)):
                moveS4LoopOrJump(deck, detents: detents, shifted: shifted)
            case .loopRecall(let deck, stop: false):
                if let state = playbackSnapshot?[deck], !state.loopEnabled,
                    s4MK1Performance.loopRecall[deck]?.generation != state.generation
                {
                    applyNativeMK2Event(.loopSet(deck), stateKey: \.s4MK1Performance)
                } else {
                    applyNativeMK2Event(event, stateKey: \.s4MK1Performance)
                }
            case .tempoReset(let deck) where playbackSnapshot?[deck].synced == true || loaded[deck] == nil:
                s4MK1Controls.unlockTempo(deck)
            case .tempoPickup(let deck, _) where playbackSnapshot?[deck].synced == true || loaded[deck] == nil:
                break
            case .pot(.tempoA, let deck, _), .pot(.tempoB, let deck, _):
                if playbackSnapshot?[deck].synced != true {
                    applyNativeMK2Event(event, stateKey: \.s4MK1Performance)
                }
            default:
                applyNativeMK2Event(event, stateKey: \.s4MK1Performance)
            }
        }

        private func releaseS4MK1Bridge() {
            s4MK1Receiving = false
            for deck in s4MK1Controls.touched {
                applyTraktorDeckAction(deck.leftSide ? .jogTouchA : .jogTouchB, deck: deck, value: 0, quantized: false)
            }
            for deck in s4MK1Controls.bent { resetControllerWheelJog(deck) }
            for deck in DeckID.allCases { releaseS4PerformanceContacts(deck, stateKey: \.s4MK1Performance) }
            for (deck, effects) in s4MK1Performance.previousFX where playback.generations[deck] != nil {
                for (slot, effect) in effects.enumerated() { setEffect(effect, slot: slot, deck: deck) }
            }
            s4MK1Controls = .init()
            s4MK1Performance = .init()
        }

        func maintainS4MK1Bridge() {
            guard let bridge = s4MK1Bridge else { return }
            bridge.poll()
            if s4MK1Receiving != bridge.isReceiving { s4MK1Receiving = bridge.isReceiving }
            guard bridge.isReceiving, let snapshot = playbackSnapshot else { return }

            var feedback = S4MK2Lights.Feedback()
            feedback.quantize = s4MK1Performance.quantize
            feedback.samples = playback.core.playingPads
            feedback.sampleSlots = Set(s2SampleSlots.keys)
            feedback.fxDecks = s4MK1Performance.fx.map(\.decks)
            feedback.fxActive = s4MK1Performance.fx.map(\.enabled)
            feedback.fxSlots = s4MK1Performance.fx.map(\.slots)
            var cueKinds: [DeckID: [Int: PerformanceCueKind]] = [:]
            for deck in DeckID.allCases {
                let state = snapshot[deck]
                if state.phase == .playing {
                    feedback.frames[deck] = playback.core.asset(generation: state.generation)?.frames
                }
                feedback.cueHeld[deck] = s4MK1Performance.cueContacts[deck]?.generation == state.generation
                feedback.loopMarked[deck] = s4MK1Performance.loopIn[deck]?.generation == state.generation
                feedback.loops[deck] = performance.loopBeats(for: deck)
                if let track = loaded[deck], let cues = performance.cues[track] {
                    cueKinds[deck] = cues.mapValues(\.category)
                }
            }
            let tempo = s4MK1Controls.layers.map { (deckTempoPercent(deck: $0) + 8) / 16 }
            bridge.feedback(
                S4MK1Lights.report(
                    snapshot: snapshot, controls: s4MK1Controls, feedback: feedback, cueKinds: cueKinds,
                    snap: s4MK1Performance.snap, browsing: browserVisible, tempo: tempo))
        }
    }
#endif
