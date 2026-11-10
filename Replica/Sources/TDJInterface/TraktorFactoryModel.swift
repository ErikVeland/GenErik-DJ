#if os(iOS)
    import AVFoundation
    import Foundation
    import TDJCore

    struct TraktorVinylContact {
        var generation: UInt64 = 0
        var stamp: UInt64 = 0
        var updated: ContinuousClock.Instant?
        var speed = 0.0
        var applied = 0.0
    }

    @MainActor final class TraktorFactorySession {
        let model: TraktorFactoryModel
        let bridge: TraktorHIDBridgeConnection
        var controls: TraktorFactoryControls
        var decks: [DeckID]
        var shifts: Set<TraktorFactoryProfile.Target> = []
        var sampleDecks: Set<DeckID> = []
        var loopDecks: Set<DeckID> = []
        var stemDecks: Set<DeckID> = []
        var heldStem: [DeckID: Int] = [:]
        var rollPads: [DeckID: Int] = [:]
        var cuePlay: Set<DeckID> = []
        var gridDecks: Set<DeckID> = []
        var hotcueMode = false
        var touched: Set<DeckID> = []
        var reversing: Set<DeckID> = []
        var heldCues: Set<DeckID> = []
        var heldPads: [DeckID: Set<Int>] = [:]
        var mixerFX = 4
        var patterns = [TraktorPatternUnit(), TraktorPatternUnit()]
        var nextSample = 0
        var nextScreenUpdate: ContinuousClock.Instant?
        var captureTask: Task<Void, Never>?
        var liveInputs = Set<DeckID>()
        var microphone = false
        var timecode = Set<DeckID>()
        var vinylContacts: [DeckID: TraktorVinylContact] = [:]

        var audioDevice: String { "\(model.rawValue) Bridge" }
        var needsCapture: Bool { microphone || !liveInputs.isEmpty || !timecode.isEmpty }

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
            stemDecks = []
            heldStem = [:]
            rollPads = [:]
            cuePlay = []
            gridDecks = []
            hotcueMode = false
            touched = []
            reversing = []
            heldCues = []
            heldPads = [:]
            mixerFX = 4
            patterns = [TraktorPatternUnit(), TraktorPatternUnit()]
            nextSample = 0
            nextScreenUpdate = nil
            captureTask?.cancel()
            captureTask = nil
            liveInputs = []
            microphone = false
            timecode = []
            vinylContacts = [:]
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
                if model == .z2, !session.timecode.isEmpty { maintainFactoryTimecode(session, now: now) }
                if let snapshot = playbackSnapshot {
                    for report in factoryLights(session, snapshot: snapshot) { session.bridge.feedback(report) }
                    if [.d2, .s5, .s8].contains(model), session.nextScreenUpdate.map({ now >= $0 }) ?? true {
                        session.nextScreenUpdate = now + .milliseconds(250)
                        updateHardwareScreens(session.bridge, decks: session.decks, snapshot: snapshot)
                    }
                }
            }
            if receivingFactoryControllers != receiving { receivingFactoryControllers = receiving }
        }

        func updateHardwareScreens(_ bridge: TraktorHIDBridgeConnection, decks: [DeckID], snapshot: PlaybackSnapshot) {
            for (side, deck) in decks.enumerated() {
                let state = snapshot[deck]
                let asset = playback.core.asset(generation: state.generation)
                let rate = asset?.sampleRate ?? 48_000
                let flags: UInt8 = (state.phase.active ? 1 : 0) | (state.synced ? 2 : 0)
                    | (state.loopEnabled ? 4 : 0) | (state.generation != 0 ? 8 : 0)
                let bpm = state.synced ? snapshot.masterBPM : state.sourceBPM * state.freeRate
                let track = track(deck)
                let screen = TraktorFactoryScreen(
                    side: UInt8(side), deck: UInt8(deck.transportIndex), flags: flags,
                    position: state.sourceFrame / rate, duration: Double(asset?.frames ?? 0) / rate,
                    bpm: bpm, title: track?.title ?? "")
                bridge.factoryScreen(screen.payload)
                let content = browserVisible
                    ? TraktorFactoryScreenContent.browser(side: UInt8(side), rows: factoryBrowserRows, selected: factoryBrowserSelection)
                    : TraktorFactoryScreenContent.waveform(
                        side: UInt8(side), analysis: track?.analysis,
                        progress: asset.map { state.sourceFrame / Double(max(1, $0.frames)) } ?? 0)
                bridge.factoryScreen(content, content: true)
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

        func primeTraktorFactoryMixer(_ deck: DeckID) -> Bool {
            let mixers: [TraktorFactoryModel] = [.s5, .s8, .z2]
            let available = mixers.filter { factorySessions[$0]?.bridge.isReceiving == true }
            let active = available.first { automaticOutputDevice == "\($0.rawValue) Bridge" } ?? available.first
            if let active { primeS4Mixer(deck, stateKey: \ReplicaModel.[factory: active]) }
            for (model, session) in factorySessions where model != active && session.bridge.isReceiving {
                let stateKey = \ReplicaModel.[factory: model]
                if self[keyPath: stateKey].fx.contains(where: { $0.decks.contains(deck) }) {
                    primeS4Mixer(deck, stateKey: stateKey, primePots: false)
                }
            }
            return active != nil
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
            if [.z2, .s8, .mx2].contains(session.model), session.needsCapture {
                try? playback.setFactoryCapture(false, device: session.audioDevice)
            }
            for deck in DeckID.primary { releaseFactoryVinyl(deck, session: session) }
            if session.model == .mx2 {
                for unit in 0..<2 { playback.core.setPatternUnit(UInt32(unit), settings: 0) }
            }
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
            session.heldStem[deck] = nil
            if session.rollPads.removeValue(forKey: deck) != nil {
                setNativeTraktorRoll(deck: deck, held: false, quantized: true)
            }
            session.heldPads[deck] = nil
            if session.gridDecks.remove(deck) != nil { endS2Grid(deck: deck, save: false) }
            releaseS4PerformanceContacts(deck, stateKey: \ReplicaModel.[factory: session.model])
        }

        private func updateFactoryCapture(_ session: TraktorFactorySession) {
            if !session.needsCapture {
                session.captureTask?.cancel()
                session.captureTask = nil
                try? playback.setFactoryCapture(false, device: session.audioDevice)
                return
            }
            guard session.captureTask == nil else { return }
            session.captureTask = Task { [weak self, weak session] in
                guard let self, let session else { return }
                defer { session.captureTask = nil }
                let allowed: Bool
                switch AVAudioApplication.shared.recordPermission {
                case .granted: allowed = true
                case .undetermined: allowed = await AVAudioApplication.requestRecordPermission()
                default: allowed = false
                }
                guard !Task.isCancelled, session.bridge.isReceiving, session.needsCapture else { return }
                do {
                    guard allowed else {
                        throw TransportError.cache("Allow microphone access to use the controller inputs.")
                    }
                    guard playback.canOpenCapture(device: session.audioDevice) else {
                        throw TransportError.cache("Pause playback before opening the controller inputs.")
                    }
                    cancelNativeMusicAnalysis()
                    if session.model == .s8 {
                        let core = playback.core
                        try await Task.detached(priority: .utility) { try core.prepareExtraDecks() }.value
                        guard !Task.isCancelled, session.bridge.isReceiving, session.needsCapture else { return }
                    }
                    let mask = session.liveInputs.reduce(UInt32(0)) { $0 | (1 << $1.transportIndex) }
                    try playback.setFactoryCapture(true, device: session.audioDevice, mask: mask, mic: session.microphone)
                    if session.model == .s8 {
                        let key = \ReplicaModel.[factory: session.model]
                        for deck in session.liveInputs where playback.generations[deck] == nil {
                            let pots = self[keyPath: key].extraPots[deck, default: [:]]
                            for (action, value) in pots {
                                applyNativeMK2Event(.pot(action, deck, value), stateKey: key)
                            }
                        }
                    }
                } catch {
                    session.microphone = false
                    session.liveInputs = []
                    session.timecode = []
                    for deck in DeckID.primary { releaseFactoryVinyl(deck, session: session) }
                    status = error.localizedDescription
                }
            }
        }

        private func maintainFactoryTimecode(_ session: TraktorFactorySession, now: ContinuousClock.Instant) {
            for deck in session.timecode {
                guard playback.factoryCaptureActive(session.audioDevice), let state = playbackSnapshot?[deck],
                    state.generation != 0, state.phase != .ended, !preparingPlayback.contains(deck),
                    !state.loopRolling, !state.braking, let asset = playback.core.asset(generation: state.generation)
                else {
                    releaseFactoryVinyl(deck, session: session)
                    continue
                }
                let reading = playback.core.factoryTimecode(side: UInt32(deck.transportIndex))
                var contact = session.vinylContacts[deck] ?? .init()
                if contact.generation != 0 && contact.generation != state.generation { contact = .init() }
                if contact.stamp != reading.stamp {
                    contact.stamp = reading.stamp
                    contact.updated = now
                    contact.speed = reading.rate ?? 0
                } else if let updated = contact.updated, now - updated >= .milliseconds(100) {
                    contact.speed = 0
                }
                if contact.generation == 0 && (contact.speed == 0 || state.touchActive) {
                    session.vinylContacts[deck] = contact
                    continue
                }
                if contact.generation == 0 || abs(contact.applied - contact.speed) >= 0.008 {
                    let position = min(Double(asset.frames - 1), max(0, state.sourceFrame))
                    do {
                        try playback.perform(.touch, deck: deck, value: position, touchRate: contact.speed)
                        contact.generation = state.generation
                        contact.applied = contact.speed
                    } catch {}
                }
                session.vinylContacts[deck] = contact
            }
        }

        private func releaseFactoryVinyl(_ deck: DeckID, session: TraktorFactorySession) {
            guard let contact = session.vinylContacts.removeValue(forKey: deck), contact.generation != 0,
                playback.generations[deck] == contact.generation
            else { return }
            try? playback.perform(.touch, deck: deck, enabled: false)
        }

        private func toggleStemMute(_ deck: DeckID, part: Int) {
            changeStem(deck) {
                if $0.muted.remove(part) == nil { $0.muted.insert(part) }
            }
        }

        private func applyStemFilterTurn(_ deck: DeckID, part: Int, detents: Int) {
            changeStem(deck) { $0.filters[part] = min(1, max(-1, $0.filters[part] + Double(detents) / 24)) }
        }

        private func applyFactoryControl(_ event: TraktorFactoryControls.Event, session: TraktorFactorySession) {
            let stateKey = \ReplicaModel.[factory: session.model]
            let deck = session.deck(event.target)
            let unit = session.fxUnit(event.target)
            let down = event.value > 0
            let shifted = session.shifted(event.target)
            let detents = Int(event.value)
            func apply(_ event: S4MK2Event) { applyNativeMK2Event(event, stateKey: stateKey) }
            func updatePattern(_ unit: Int) { playback.core.setPatternUnit(UInt32(unit), settings: session.patterns[unit].settings) }

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
            case .microphone where down:
                session.microphone.toggle()
                updateFactoryCapture(session)
            case .liveInput where down:
                if session.liveInputs.remove(deck) == nil {
                    session.liveInputs.insert(deck)
                    session.timecode.remove(deck)
                    releaseFactoryVinyl(deck, session: session)
                }
                updateFactoryCapture(session)
            case .timecode where down:
                if session.timecode.remove(deck) == nil {
                    session.timecode.insert(deck)
                    session.liveInputs.remove(deck)
                    let reading = playback.core.factoryTimecode(side: UInt32(deck.transportIndex))
                    session.vinylContacts[deck] = .init(stamp: reading.stamp)
                } else { releaseFactoryVinyl(deck, session: session) }
                updateFactoryCapture(session)
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
                if session.model == .s5, let part = session.heldStem[deck] {
                    changeStem(deck) { $0.gain[part] = min(1, max(0, $0.gain[part] + event.value / 32)) }
                } else if self[keyPath: stateKey].ownsPreview { seekS3Preview(detents: detents) }
                else { queueS2Browser(.move(detents, groups: shifted)) }
            case .load where down:
                if session.model == .s5, let part = session.heldStem[deck] {
                    toggleStemMute(deck, part: part)
                } else if session.model == .f1 {
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
            case .loop where down:
                if session.model == .s5, let part = session.heldStem[deck] {
                    changeStem(deck) { if $0.bypassed.remove(part) == nil { $0.bypassed.insert(part) } }
                } else { apply(.loopSet(deck)) }
            case .loopSize:
                if let part = session.heldStem[deck] {
                    applyStemFilterTurn(deck, part: part, detents: detents)
                } else if s2Grids[deck] != nil { apply(.native(.gridMove(deck, detents))) }
                else { apply(.native(.loopSize(deck, detents, shifted: shifted))) }
            case .loopMark(let end) where down: apply(.loopMark(deck, end: end))
            case .move:
                if let part = session.heldStem[deck] {
                    changeStem(deck) { $0.gain[part] = min(1, max(0, $0.gain[part] + event.value / 32)) }
                } else { apply(.native(.move(deck, detents, shifted: shifted))) }
            case .tempo: apply(.tempoPickup(deck, event.value))
            case .masterTempo: apply(.masterTempo(detents))
            case .jump(let direction) where down:
                moveS4LoopOrJump(deck, detents: direction, shifted: shifted)
            case .pad(let slot):
                if session.stemDecks.contains(deck), isStemDeck(deck) {
                    if slot < 4, down { toggleStemMute(deck, part: slot) }
                    if slot >= 4 {
                        if down { session.heldStem[deck] = slot - 4 }
                        else if session.heldStem[deck] == slot - 4 { session.heldStem[deck] = nil }
                    }
                } else if down, session.model == .mx2, session.patterns[unit].page != nil {
                    session.patterns[unit].toggleStep(slot)
                    updatePattern(unit)
                } else if !down, session.rollPads[deck] == slot {
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
            case .stemPads where down:
                if isStemDeck(deck) {
                    session.stemDecks.insert(deck)
                    session.patterns[unit].page = nil
                }
            case .stemGain(let part):
                changeStem(deck) { $0.gain[part] = event.value }
            case .stemFilter(let part):
                changeStem(deck) { $0.filters[part] = 2 * event.value - 1 }
            case .stemFilterTurn(let part):
                applyStemFilterTurn(deck, part: part, detents: detents)
            case .stemFilterToggle(let part) where down:
                changeStem(deck) {
                    if $0.bypassed.remove(part) == nil { $0.bypassed.insert(part) }
                }
            case .patternPads where down:
                session.stemDecks.remove(deck)
                session.heldStem[deck] = nil
                session.patterns[unit].selectPage(shifted: shifted)
                updatePattern(unit)
            case .hotcues where down:
                session.stemDecks.remove(deck)
                session.heldStem[deck] = nil
                session.patterns[unit].page = nil
                if session.model == .x1MK1 { session.hotcueMode.toggle() }
                session.sampleDecks.remove(deck)
                session.loopDecks.remove(deck)
                if self[keyPath: stateKey].slices[deck] != nil { apply(.sliceMode(deck)) }
            case .samples where down:
                if self[keyPath: stateKey].slices[deck] != nil { apply(.sliceMode(deck)) }
                session.loopDecks.remove(deck)
                if session.model == .s5, isStemDeck(deck) {
                    session.stemDecks.insert(deck)
                    session.sampleDecks.remove(deck)
                } else {
                    session.sampleDecks.insert(deck)
                }
            case .loopPads where down:
                session.stemDecks.remove(deck)
                session.heldStem[deck] = nil
                session.patterns[unit].page = nil
                if self[keyPath: stateKey].slices[deck] != nil { apply(.sliceMode(deck)) }
                session.sampleDecks.remove(deck)
                session.loopDecks.insert(deck)
            case .freeze where down:
                session.sampleDecks.remove(deck)
                session.loopDecks.remove(deck)
                apply(.sliceMode(deck))
            case .grid where down:
                if session.gridDecks.remove(deck) != nil {
                    endS2Grid(deck: deck, save: true)
                } else if s2Grids[deck] == nil, s2MetronomeGenerations[deck] == nil {
                    apply(.gridToggle(deck))
                    if s2Grids[deck] != nil || s2MetronomeGenerations[deck] != nil {
                        session.gridDecks.insert(deck)
                    }
                }
            case .quantize where down: apply(.quantize)
            case .sample(let slot) where down:
                session.nextSample = slot
                pressS2Sample(slot: slot, shifted: shifted)
            case .stopSampleColumn(let column) where down:
                if isStemDeck(deck) {
                    toggleStemMute(deck, part: column)
                    return
                }
                for slot in stride(from: column, to: 16, by: 4) {
                    if let generation = s2SampleSlots[slot] {
                        try? playback.triggerPad(slot, generation: generation, enabled: false)
                    }
                }
            case .fxButton(let slot) where down:
                if session.model == .mx2, session.patterns[unit].button(slot, shifted: shifted) {
                    if slot == 0 && shifted, session.patterns[unit].mode == 2 {
                        session.patterns[unit].decks = self[keyPath: stateKey].fx[unit].decks
                    }
                    updatePattern(unit)
                } else { apply(.fxEnable(unit, slot == 0 ? nil : slot - 1)) }
            case .fxKnob(let knob):
                if session.model == .mx2, session.patterns[unit].mode == 2 {
                    session.patterns[unit].knob(knob, value: event.value)
                    updatePattern(unit)
                } else { apply(.fxPot(unit, knob, event.value)) }
            case .fxAssign(let unit) where down:
                if session.model == .mx2, session.patterns[unit].mode == 2 {
                    if session.patterns[unit].decks.remove(deck) == nil { session.patterns[unit].decks.insert(deck) }
                    updatePattern(unit)
                } else { apply(.fxAssign(unit, deck)) }
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
