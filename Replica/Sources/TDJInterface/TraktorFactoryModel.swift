#if os(iOS)
    import Foundation
    import TDJCore

    @MainActor final class TraktorFactorySession {
        let model: TraktorFactoryModel
        let bridge: TraktorHIDBridgeConnection
        var controls: TraktorFactoryControls
        var decks: [DeckID]
        var shifts: Set<TraktorFactoryProfile.Target> = []
        var sampleDecks: Set<DeckID> = []
        var loopDecks: Set<DeckID> = []
        var rollPads: [DeckID: Int] = [:]
        var cuePlay: Set<DeckID> = []
        var hotcueMode = false
        var touched: Set<DeckID> = []
        var reversing: Set<DeckID> = []
        var heldCues: Set<DeckID> = []
        var heldPads: [DeckID: Set<Int>] = [:]
        var mixerFX = 4
        var nextSample = 0
        var nextScreenUpdate: ContinuousClock.Instant?

        init(_ model: TraktorFactoryModel) {
            self.model = model
            bridge = .init(.factory(model))
            controls = .init(model)
            decks = model.defaultDecks
        }

        func deck(_ target: TraktorFactoryProfile.Target) -> DeckID {
            switch target {
            case .surface(let side): decks[side]
            case .channel(let deck): deck
            }
        }

        func fxUnit(_ target: TraktorFactoryProfile.Target) -> Int {
            if case .surface(let side) = target { return side }
            return deck(target).leftSide ? 0 : 1
        }

        func shifted(_ target: TraktorFactoryProfile.Target) -> Bool {
            shifts.contains(target) || ([.x1MK1, .x1MK2, .z2].contains(model) && shifts.contains(.surface(0)))
        }

        func reset() {
            controls = .init(model)
            decks = model.defaultDecks
            shifts = []
            sampleDecks = []
            loopDecks = []
            rollPads = [:]
            cuePlay = []
            hotcueMode = false
            touched = []
            reversing = []
            heldCues = []
            heldPads = [:]
            mixerFX = 4
            nextSample = 0
            nextScreenUpdate = nil
        }
    }

    extension ReplicaModel {
        subscript(factory controller: TraktorFactoryModel) -> S4MK2Performance {
            get { factoryPerformance[controller] ?? .init() }
            set { factoryPerformance[controller] = newValue }
        }

        func maintainTraktorFactoryBridges() {
            guard !playback.offline else { return }
            let now = ContinuousClock.now
            if nextFactoryDiscovery.map({ now >= $0 }) ?? true {
                nextFactoryDiscovery = now + .seconds(1)
                let available = TraktorHIDBridgeConnection.availableFactoryModels()
                for model in TraktorFactoryModel.allCases {
                    if available.contains(model) {
                        if factorySessions[model] == nil { startTraktorFactoryBridge(model) }
                    } else if let session = factorySessions.removeValue(forKey: model) {
                        session.bridge.stop()
                    }
                }
            }
            guard !factorySessions.isEmpty else {
                if !receivingFactoryControllers.isEmpty { receivingFactoryControllers = [] }
                return
            }
            var receiving: [TraktorFactoryModel] = []
            for model in TraktorFactoryModel.allCases {
                guard let session = factorySessions[model] else { continue }
                session.bridge.poll()
                guard session.bridge.isReceiving else { continue }
                receiving.append(model)
                if let snapshot = playbackSnapshot {
                    for report in factoryLights(session, snapshot: snapshot) { session.bridge.feedback(report) }
                    if [.d2, .s5, .s8].contains(model), session.nextScreenUpdate.map({ now >= $0 }) ?? true {
                        session.nextScreenUpdate = now + .seconds(1)
                        updateFactoryScreens(session, snapshot: snapshot)
                    }
                }
            }
            if receivingFactoryControllers != receiving { receivingFactoryControllers = receiving }
        }

        private func updateFactoryScreens(_ session: TraktorFactorySession, snapshot: PlaybackSnapshot) {
            for (side, deck) in session.decks.enumerated() {
                let state = snapshot[deck]
                let asset = playback.core.asset(generation: state.generation)
                let rate = asset?.sampleRate ?? 48_000
                let flags: UInt8 = (state.phase.active ? 1 : 0) | (state.synced ? 2 : 0)
                    | (state.loopEnabled ? 4 : 0) | (state.generation != 0 ? 8 : 0)
                let bpm = state.synced ? snapshot.masterBPM : state.sourceBPM * state.freeRate
                let screen = TraktorFactoryScreen(
                    side: UInt8(side), deck: UInt8(deck.transportIndex), flags: flags,
                    position: state.sourceFrame / rate, duration: Double(asset?.frames ?? 0) / rate,
                    bpm: bpm, title: track(deck)?.title ?? "")
                session.bridge.factoryScreen(screen.payload)
            }
        }

        private func startTraktorFactoryBridge(_ model: TraktorFactoryModel) {
            let session = TraktorFactorySession(model)
            session.bridge.onReport = { [weak self, weak session] report in
                guard let self, let session else { return }
                let events = session.controls.consume(report)
                for event in events where event.control == .shift {
                    if event.value > 0 { session.shifts.insert(event.target) } else { session.shifts.remove(event.target) }
                }
                for event in events where event.control != .shift { applyFactoryControl(event, session: session) }
            }
            session.bridge.onDisconnect = { [weak self, weak session] in
                guard let self, let session else { return }
                releaseFactorySession(session)
            }
            factorySessions[model] = session
            session.bridge.start()
        }

        func stopTraktorFactoryBridges() {
            for session in factorySessions.values { session.bridge.stop() }
            factorySessions.removeAll()
            receivingFactoryControllers = []
            nextFactoryDiscovery = nil
        }

        private func releaseFactorySession(_ session: TraktorFactorySession) {
            let stateKey = \ReplicaModel.[factory: session.model]
            for deck in DeckID.allCases {
                releaseFactoryDeck(deck, session: session)
                if let previous = self[keyPath: stateKey].previousFX[deck], playback.generations[deck] != nil {
                    for (slot, effect) in previous.enumerated() { setEffect(effect, slot: slot, deck: deck) }
                }
            }
            if self[keyPath: stateKey].ownsPreview { stopS3Preview() }
            factoryPerformance[session.model] = nil
            session.reset()
        }

        private func releaseFactoryDeck(_ deck: DeckID, session: TraktorFactorySession) {
            if session.reversing.remove(deck) != nil {
                applyNativeTraktorEvent(.reverse(deck, false), isS3: false)
            }
            if session.touched.remove(deck) != nil {
                applyTraktorDeckAction(.jogTouchA, deck: deck, value: 0, quantized: true)
            }
            session.heldCues.remove(deck)
            session.cuePlay.remove(deck)
            if session.rollPads.removeValue(forKey: deck) != nil {
                setNativeTraktorRoll(deck: deck, held: false, quantized: true)
            }
            session.heldPads[deck] = nil
            releaseS4PerformanceContacts(deck, stateKey: \ReplicaModel.[factory: session.model])
        }

        private func applyFactoryControl(_ event: TraktorFactoryControls.Event, session: TraktorFactorySession) {
            let stateKey = \ReplicaModel.[factory: session.model]
            let deck = session.deck(event.target)
            let unit = session.fxUnit(event.target)
            let down = event.value > 0
            let shifted = session.shifted(event.target)
            let detents = Int(event.value)
            func apply(_ event: S4MK2Event) { applyNativeMK2Event(event, stateKey: stateKey) }

            if session.model == .x1MK1, session.hotcueMode, down, let slot = event.control.x1HotcueSlot {
                cue(slot: slot, deck: deck, delete: shifted, quantized: self[keyPath: stateKey].quantize)
                return
            }

            switch event.control {
            case .shift: break
            case .play where down: apply(.cueLatch(deck))
            case .cue:
                if down {
                    session.heldCues.insert(deck)
                    apply(.cue(deck, held: true))
                } else if session.heldCues.remove(deck) != nil {
                    apply(.cue(deck, held: false))
                }
            case .cuePlay:
                if down {
                    session.cuePlay.insert(deck)
                    pressS4Cue(deck, stateKey: stateKey, recallStored: true)
                } else if session.cuePlay.remove(deck) != nil {
                    if self[keyPath: stateKey].cueContacts[deck] != nil {
                        finishS4Cue(deck, continuePlaying: true, stateKey: stateKey)
                    } else {
                        pressPlay(deck: deck, vinylStop: false)
                    }
                }
            case .sync where down: apply(.action(.syncA, deck, 1))
            case .keylock where down: apply(.action(.keylockA, deck, 1))
            case .flux where down: apply(.native(.flux(deck)))
            case .reverse:
                if down {
                    session.reversing.insert(deck)
                } else if session.reversing.remove(deck) == nil {
                    return
                }
                apply(.native(.reverse(deck, down)))
            case .clockMaster where down:
                guard let snapshot = playbackSnapshot, snapshot[deck].timing != nil else { return }
                let current = snapshot[deck]
                let bpm = current.synced ? snapshot.masterBPM : current.sourceBPM * current.freeRate
                do { try playback.setControllerClock(bpm, reference: deck) } catch { status = error.localizedDescription }
            case .layer(let selection) where down:
                guard case .surface(let side) = event.target else { return }
                let next = selection ?? (session.decks.count == 1
                    ? DeckID.allCases[(Int(deck.transportIndex) + 1) % DeckID.allCases.count]
                    : (deck.leftSide ? (deck == .a ? .c : .a) : (deck == .b ? .d : .b)))
                guard next != deck else { return }
                releaseFactoryDeck(deck, session: session)
                session.decks[side] = next
                self[keyPath: stateKey].takeover[next] = nil
            case .browser where down: apply(.native(.browserView))
            case .browse:
                if self[keyPath: stateKey].ownsPreview { seekS3Preview(detents: detents) }
                else { queueS2Browser(.move(detents, groups: shifted)) }
            case .load where down:
                if session.model == .f1 {
                    if shifted { queueS2Browser(.openGroup) }
                    else if s2SampleSlots[session.nextSample] == nil { queueS2Browser(.sample(session.nextSample)) }
                } else if shifted && session.model == .mx2 {
                    queueS2Browser(.openGroup)
                } else if shifted {
                    apply(.native(.eject(deck)))
                } else {
                    queueS2Browser(.load(deck))
                }
            case .prepare where down: queueS2Browser(.prepare(top: shifted))
            case .preview:
                if down, automaticOutputDevice == "MX2 Bridge" {
                    stopS3Preview()
                    self[keyPath: stateKey].ownsPreview = true
                    s3PreviewHeld = true
                    queueS2Browser(.previewS3)
                } else if self[keyPath: stateKey].ownsPreview {
                    self[keyPath: stateKey].ownsPreview = false
                    stopS3Preview()
                }
            case .loop where down: apply(.loopSet(deck))
            case .loopSize:
                if s2Grids[deck] != nil { apply(.native(.gridMove(deck, detents))) }
                else { apply(.native(.loopSize(deck, detents, shifted: shifted))) }
            case .loopMark(let end) where down: apply(.loopMark(deck, end: end))
            case .move: apply(.native(.move(deck, detents, shifted: shifted)))
            case .tempo: apply(.tempoPickup(deck, event.value))
            case .masterTempo: apply(.masterTempo(detents))
            case .jump(let direction) where down:
                moveS4LoopOrJump(deck, detents: direction, shifted: shifted)
            case .pad(let slot):
                if !down, session.rollPads[deck] == slot {
                    session.rollPads[deck] = nil
                    setNativeTraktorRoll(deck: deck, held: false, quantized: true)
                } else if down && session.loopDecks.contains(deck) {
                    let beats = pow(2, Double(slot - 4))
                    let quantized = self[keyPath: stateKey].quantize
                    if shifted {
                        if playbackSnapshot?[deck].loopEnabled != true { setLoopSize(beats, deck: deck) }
                        toggleLoop(deck: deck, quantized: quantized)
                    } else if session.rollPads[deck] == nil, s2RollGenerations[deck] == nil {
                        setNativeTraktorRoll(deck: deck, held: true, quantized: quantized, beats: beats)
                        if s2RollGenerations[deck] != nil { session.rollPads[deck] = slot }
                    }
                } else if down && session.sampleDecks.contains(deck) {
                    pressS2Sample(slot: Int(deck.transportIndex) * 8 + slot, shifted: shifted)
                } else if down, self[keyPath: stateKey].slices[deck] == nil {
                    cue(slot: slot, deck: deck, delete: shifted, quantized: self[keyPath: stateKey].quantize)
                } else if down {
                    session.heldPads[deck, default: []].insert(slot)
                    apply(.pad(deck, slot, held: true, shifted: shifted))
                } else if session.heldPads[deck]?.remove(slot) != nil {
                    apply(.pad(deck, slot, held: false, shifted: shifted))
                }
            case .hotcues where down:
                if session.model == .x1MK1 { session.hotcueMode.toggle() }
                session.sampleDecks.remove(deck)
                session.loopDecks.remove(deck)
                if self[keyPath: stateKey].slices[deck] != nil { apply(.sliceMode(deck)) }
            case .samples where down:
                if self[keyPath: stateKey].slices[deck] != nil { apply(.sliceMode(deck)) }
                session.loopDecks.remove(deck)
                session.sampleDecks.insert(deck)
            case .loopPads where down:
                if self[keyPath: stateKey].slices[deck] != nil { apply(.sliceMode(deck)) }
                session.sampleDecks.remove(deck)
                session.loopDecks.insert(deck)
            case .freeze where down:
                session.sampleDecks.remove(deck)
                session.loopDecks.remove(deck)
                apply(.sliceMode(deck))
            case .grid where down:
                if s2Grids[deck] == nil { apply(.gridToggle(deck)) }
                else { apply(.native(.gridEnd(deck))) }
            case .quantize where down: apply(.quantize)
            case .sample(let slot) where down:
                session.nextSample = slot
                pressS2Sample(slot: slot, shifted: shifted)
            case .stopSampleColumn(let column) where down:
                for slot in stride(from: column, to: 16, by: 4) {
                    if let generation = s2SampleSlots[slot] {
                        try? playback.triggerPad(slot, generation: generation, enabled: false)
                    }
                }
            case .fxButton(let slot) where down: apply(.fxEnable(unit, slot == 0 ? nil : slot - 1))
            case .fxKnob(let knob): apply(.fxPot(unit, knob, event.value))
            case .fxAssign(let unit) where down: apply(.fxAssign(unit, deck))
            case .mixerFX(let index) where down:
                session.mixerFX = index
                let choices: [S2MixerFX] = [.reverb, .delay, .flanger, .gater, .filter]
                apply(.native(.fx(choices[index], Set(session.decks))))
            case .pot(let action):
                if action == .master || action == .monitor, automaticOutputDevice == "\(session.model.rawValue) Bridge" {
                    return
                }
                apply(.pot(action, deck, event.value))
            case .mixerButton(let action) where down: apply(.action(action, deck, 1))
            case .mixerSwitch(let action):
                _ = submitMixer(action == .cueA ? .cue : .filterEnabled, value: event.value, deck: deck)
            case .crossfaderAssign:
                let assign: CrossfaderAssignment = detents == 0 ? .left : detents == 2 ? .right : .through
                _ = submitMixer(.crossfaderAssignment, value: Double(assign.rawValue), deck: deck)
            case .jogTouch:
                if down {
                    session.touched.insert(deck)
                } else if session.touched.remove(deck) == nil {
                    return
                }
                apply(.action(.jogTouchA, deck, event.value))
            case .jog, .strip:
                let touched = session.touched.contains(deck)
                let value = min(1, max(0, 0.5 + event.value / (touched ? 128 : 32)))
                apply(.action(touched ? .jogA : .wheelJogA, deck, value))
            default: break
            }
        }
    }
#endif
