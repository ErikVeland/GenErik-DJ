#if os(iOS)
    import TDJCore

    extension ReplicaModel {
        func startS2MK1Bridge() {
            guard s2MK1Bridge == nil else { return }
            let bridge = TraktorHIDBridgeConnection(.s2MK1)
            bridge.onReport = { [weak self] report in
                guard let self else { return }
                let snapshot = playbackSnapshot
                let events = s2MK1Controls.consume(report) {
                    snapshot?[$0].loopEnabled == true && snapshot?[$0].loopRolling != true
                }
                for event in events { applyS2MK1Event(event) }
            }
            bridge.onDisconnect = { [weak self] in self?.releaseS2MK1Controls() }
            s2MK1Bridge = bridge
            bridge.start()
        }

        private func applyS2MK1Event(_ event: S4MK2Event) {
            switch event {
            case .pad(let deck, let slot, let held, let shifted) where s2MK1Controls.samples.contains(deck):
                if held { pressS2Sample(slot: S2MK3Controls.sampleSlot(deck: deck, pad: slot), shifted: shifted) }
            case .native(.move(let deck, let detents, let shifted)):
                let beats = Double(detents) * (shifted ? 1 : performance.loopBeats(for: deck))
                if playbackSnapshot?[deck].loopEnabled == true {
                    moveS3Loop(deck: deck, beats: beats)
                } else {
                    beatJump(beats: beats, deck: deck)
                }
            case .loopRecall(let deck, stop: false):
                if let state = playbackSnapshot?[deck], !state.loopEnabled,
                    s2MK1Performance.loopRecall[deck]?.generation != state.generation
                {
                    applyNativeMK2Event(.loopSet(deck), stateKey: \.s2MK1Performance)
                } else {
                    applyNativeMK2Event(event, stateKey: \.s2MK1Performance)
                }
            default:
                applyNativeMK2Event(event, stateKey: \.s2MK1Performance)
            }
        }

        func queueS2MK1LoopTrim(deck: DeckID, end: Bool, ticks: Int) {
            guard let state = playbackSnapshot?[deck], state.loopEnabled, !state.loopRolling,
                !preparingTrack.contains(deck), let asset = playback.core.asset(generation: state.generation)
            else { return }
            let current = S2MK1LoopBounds(start: state.loopStart, end: state.loopEnd)
            let previous = s2MK1LoopTrims[deck]
            let base: S2MK1LoopBounds
            if let previous, previous.generation == state.generation,
                previous.dirty || (previous.original == current && playback.preparingSourceDecks.contains(deck))
            {
                base = previous.target
            } else {
                base = current
            }
            let target = base.trimming(
                end: end, by: Double(ticks) * asset.sampleRate / 1024, frameCount: Double(asset.frames))
            guard target != base else { return }
            s2MK1LoopTrims[deck] = .init(generation: state.generation, original: current, target: target)
        }

        private func flushS2MK1LoopTrims() {
            for deck in DeckID.primary {
                guard let trim = s2MK1LoopTrims[deck], trim.dirty else { continue }
                guard let state = playbackSnapshot?[deck], state.generation == trim.generation,
                    state.loopEnabled, !state.loopRolling
                else {
                    s2MK1LoopTrims[deck] = nil
                    continue
                }
                s2MK1LoopTrims[deck]?.dirty = false
                setLoop(start: trim.target.start, end: trim.target.end, deck: deck)
            }
        }

        private func releaseS2MK1Controls() {
            for deck in s2MK1Controls.touched {
                applyTraktorDeckAction(deck.leftSide ? .jogTouchA : .jogTouchB, deck: deck, value: 0, quantized: false)
            }
            for deck in s2MK1Controls.bent { resetControllerWheelJog(deck) }
            for deck in DeckID.primary { releaseS4PerformanceContacts(deck, stateKey: \.s2MK1Performance) }
            for (deck, previous) in s2MK1Performance.previousFX where playback.generations[deck] != nil {
                for (slot, effect) in previous.enumerated() { setEffect(effect, slot: slot, deck: deck) }
            }
            s2MK1LoopTrims.removeAll()
            s2MK1Controls = .init()
            s2MK1Performance = .init(sliceCount: 4)
        }

        func maintainS2MK1Bridge() {
            guard let bridge = s2MK1Bridge else { return }
            bridge.poll()
            flushS2MK1LoopTrims()
            let connected = bridge.isReceiving
            if s2MK1Receiving != connected { s2MK1Receiving = connected }
            guard connected, let snapshot = playbackSnapshot else { return }
            var feedback = S4MK2Lights.Feedback()
            feedback.fxDecks = s2MK1Performance.fx.map(\.decks)
            feedback.fxActive = s2MK1Performance.fx.map(\.enabled)
            feedback.fxSlots = s2MK1Performance.fx.map(\.slots)
            feedback.samples = playback.core.playingPads
            feedback.sampleSlots = Set(s2SampleSlots.keys)
            var cueKinds: [DeckID: [Int: PerformanceCueKind]] = [:]
            for deck in DeckID.primary {
                let generation = snapshot[deck].generation
                feedback.frames[deck] = playback.core.asset(generation: generation)?.frames
                feedback.cueHeld[deck] = s2MK1Performance.cueContacts[deck]?.generation == generation
                feedback.loopMarked[deck] = s2MK1Performance.loopIn[deck]?.generation == generation
                if let track = loaded[deck], let cues = performance.cues[track] {
                    cueKinds[deck] = cues.mapValues(\.category)
                }
            }
            bridge.feedback(
                S2MK1Lights.report(snapshot: snapshot, controls: s2MK1Controls, feedback: feedback, cueKinds: cueKinds))
        }
    }
#endif
