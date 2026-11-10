#if os(iOS)
    import AVFoundation
    import Foundation
    import TDJCore

    struct S4MK2Performance {
        struct FXUnit {
            var decks: Set<DeckID> = []
            var enabled = true
            var slots: Set<Int> = []
            var knobs = [0.5, 0.5, 0.5, 0.5]
        }

        var slices: [DeckID: S4MK2SliceContact] = [:]
        var cueContacts: [DeckID: S4MK2CueContact] = [:]
        var cueMarks: [DeckID: S4MK2CueContact] = [:]
        var takeover: [DeckID: [ControllerAction: ControllerMIDITakeoverState]] = [:]
        var extraPots: [DeckID: [ControllerAction: Double]] = [:]
        var loopIn: [DeckID: (generation: UInt64, frame: Double)] = [:]
        var loopRecall: [DeckID: (generation: UInt64, start: Double, end: Double)] = [:]
        var jumpBeats: [DeckID: Double] = [:]
        var fx = [FXUnit(), FXUnit()]
        var previousFX: [DeckID: [EffectControl]] = [:]
        var inputTask: Task<Void, Never>?
        var inputAttempted = false
        var recordingTask: Task<Void, Never>?
        var ownsPreview = false
        var quantize = true
        var snap = true
    }

    extension ReplicaModel {
        func startS4MK2() {
            guard s4Connection == nil else { return }
            let connection = NIControllerAccessoryConnection(model: .s4MK2)
            connection.onState = { [weak self, weak connection] status, _ in
                self?.s4Status = status
                if connection?.isReceiving == true { self?.playback.core.setMasterMeterEnabled(true) }
            }
            connection.onFrame = { [weak self] frame in
                guard let self else { return }
                if frame.reportID == 1 {
                    for event in s4Controls.consume(frame.payload) { applyS4Event(event) }
                } else {
                    s4Controls.addCalibration(frame)
                }
            }
            connection.onDisconnect = { [weak self] in self?.releaseS4Controls() }
            s4Connection = connection
            do { try connection.start() } catch { s4Status = error.localizedDescription }
        }

        private func releaseS4Controls() {
            if s3Connection?.isReceiving != true { playback.core.setMasterMeterEnabled(false) }
            s4Performance.inputTask?.cancel()
            try? playback.setCaptureEnabled(false, device: "S4 Mk2")
            if s4Performance.ownsPreview { stopS3Preview() }
            for deck in s4Controls.touched {
                applyTraktorDeckAction(deck.leftSide ? .jogTouchA : .jogTouchB, deck: deck, value: 0, quantized: false)
            }
            for deck in DeckID.allCases { releaseS4PerformanceContacts(deck) }
            for deck in s4Controls.bent { resetControllerWheelJog(deck) }
            for deck in s4Controls.gridEditing { endS2Grid(deck: deck, save: false) }
            if s2Connection?.isReceiving != true, s3Connection?.isReceiving != true {
                s2SampleLoad?.cancel()
                for (slot, generation) in s2SampleSlots {
                    try? playback.triggerPad(slot, generation: generation, enabled: false)
                }
                s2BrowserCommands.removeAll()
            }
            for (deck, effects) in s4Performance.previousFX where playback.generations[deck] != nil {
                for (slot, effect) in effects.enumerated() { setEffect(effect, slot: slot, deck: deck) }
            }
            let recording = s4Performance.recordingTask
            s4Controls = .init()
            s4Performance = .init()
            s4Performance.recordingTask = recording
        }

        private func applyS4Event(_ event: S4MK2Event) {
            switch event {
            case .action(let action, let deck, let value):
                if value > 0, action.isJog || action == .jogTouchA || action == .jogTouchB {
                    releaseS4PerformanceContacts(deck)
                }
                applyTraktorDeckAction(action, deck: deck, value: value, quantized: s4Performance.quantize)
            case .sliceMode(let deck):
                toggleS4SliceMode(deck)
            case .pad(let deck, let slot, let held, let shifted):
                handleS4Pad(deck, slot: slot, held: held, shifted: shifted)
            case .cue(let deck, let held):
                if held { pressS4Cue(deck) } else { finishS4Cue(deck, continuePlaying: false) }
            case .cueLatch(let deck):
                if s4Performance.cueContacts[deck] != nil {
                    finishS4Cue(deck, continuePlaying: true)
                } else {
                    pressPlay(deck: deck, vinylStop: false)
                }
            case .pot(let action, let deck, let value):
                applyS4Pot(action, deck: deck, value: value)
            case .layer(let deck):
                releaseS4PerformanceContacts(
                    deck.leftSide
                        ? (deck == .a ? .c : .a)
                        : (deck == .b ? .d : .b))
                s4Performance.takeover[deck]?[deck.leftSide ? .tempoA : .tempoB] = nil
            case .bendEnd(let deck):
                resetControllerWheelJog(deck)
            case .native(.move(let deck, let detents, let shifted)):
                if moveS4SliceBank(deck, detents: detents, resize: shifted) { return }
                let beats = s4Performance.jumpBeats[deck, default: 4]
                if shifted {
                    s4Performance.jumpBeats[deck] = min(32, max(0.03125, beats * pow(2, Double(detents))))
                } else if playbackSnapshot?[deck].loopEnabled == true {
                    moveS3Loop(deck: deck, beats: Double(detents) * beats)
                } else {
                    beatJump(beats: Double(detents) * beats, deck: deck)
                }
            case .native(.loopSize(let deck, let detents, let shifted)):
                if shifted {
                    setDeckTempo(percent: deckTempoPercent(deck: deck) + Double(detents) * 0.1, deck: deck)
                } else {
                    applyNativeTraktorEvent(.loopSize(deck, detents, shifted: false), isS3: false)
                }
            case .native(.eject(let deck)):
                releaseS4PerformanceContacts(deck)
                ejectNativeTraktorDeck(deck)
            case .native(.park(let deck, let atCue)):
                releaseS4PerformanceContacts(deck)
                applyNativeTraktorEvent(.park(deck, atCue: atCue), isS3: false)
            case .native(let event):
                applyNativeTraktorEvent(event, isS3: false)
            case .gain(let deck, let detents):
                let action: ControllerAction = deck.leftSide ? .gainA : .gainB
                if let detents {
                    let gain = playback.core.snapshot()?[deck].mixer.gain ?? 1
                    let value = min(4, max(0.25, gain * pow(10, Double(detents) / 40)))
                    _ = submitMixer(.gain, value: value, deck: deck)
                } else {
                    applyController(action, value: 0.5, refreshMixer: false, targetDeck: deck)
                }
            case .masterTempo(let detents):
                guard let bpm = playbackSnapshot?.masterBPM, bpm > 0 else { return }
                setMasterBPM(min(300, max(30, bpm + Double(detents) * 0.1)))
            case .gridToggle(let deck):
                releaseS4PerformanceContacts(deck)
                beginS2Grid(deck: deck, anchor: false)
            case .gridDownbeat(let deck, let beat):
                selectS2GridDownbeat(deck: deck, beat: beat)
            case .loopMark(let deck, let end):
                markS4Loop(deck, end: end)
            case .loopRecall(let deck, let stop):
                if let state = playbackSnapshot?[deck] {
                    if state.loopEnabled, !stop {
                        s4Performance.loopRecall[deck] = (state.generation, state.loopStart, state.loopEnd)
                        perform(.loop, deck: deck, enabled: false)
                    } else if let loop = s4Performance.loopRecall[deck], loop.generation == state.generation {
                        if stop && state.phase.active { pressPlay(deck: deck, vinylStop: false) }
                        setLoop(
                            start: loop.start, end: loop.end, deck: deck, quantized: s4Performance.quantize && !stop)
                    }
                }
            case .loopSet(let deck):
                guard let state = playbackSnapshot?[deck] else { return }
                if state.loopEnabled {
                    s4Performance.loopRecall[deck] = (state.generation, state.loopStart, state.loopEnd)
                }
                toggleLoop(deck: deck, quantized: s4Performance.snap)
            case .tempoReset(let deck):
                setDeckTempo(percent: 0, deck: deck)
                s4Performance.takeover[deck]?[deck.leftSide ? .tempoA : .tempoB] = nil
            case .record:
                guard s4Performance.recordingTask == nil, !recordingFinishing else { return }
                s4Performance.recordingTask = Task { [weak self] in
                    guard let self else { return }
                    defer { s4Performance.recordingTask = nil }
                    await toggleRecording()
                }
            case .preview:
                guard automaticOutputDevice == "S4 Mk2" else { return }
                let active = s4Performance.ownsPreview && s3PreviewHeld
                stopS3Preview()
                s4Performance.ownsPreview = !active
                if !active {
                    s3PreviewHeld = true
                    queueS2Browser(.previewS3)
                }
            case .quantize:
                s4Performance.quantize.toggle()
            case .snap:
                s4Performance.snap.toggle()
            case .fxAssign(let unit, let deck):
                if s4Performance.fx[unit].decks.remove(deck) == nil { s4Performance.fx[unit].decks.insert(deck) }
                applyS4FX(deck)
            case .fxEnable(let unit, let slot):
                if let slot {
                    if s4Performance.fx[unit].slots.remove(slot) == nil { s4Performance.fx[unit].slots.insert(slot) }
                } else {
                    s4Performance.fx[unit].enabled.toggle()
                }
                for deck in s4Performance.fx[unit].decks { applyS4FX(deck) }
            case .fxPot(let unit, let knob, let value):
                s4Performance.fx[unit].knobs[knob] = value
                for deck in s4Performance.fx[unit].decks { applyS4FX(deck, slot: knob == 0 ? nil : knob - 1) }
            }
        }

        private func applyS4Pot(_ action: ControllerAction, deck: DeckID, value: Double) {
            if deck.transportIndex >= 2 {
                s4Performance.extraPots[deck, default: [:]][action] = value
                if playback.generations[deck] == nil {
                    if playback.s4InputChannels > 0, action != .tempoA, action != .tempoB {
                        setS4Pot(action, deck: deck, value: value)
                    }
                    return
                }
            }
            guard
                s4Performance.takeover[deck, default: [:]][action, default: .init()]
                    .shouldApply(input: value, target: controllerValue(action, targetDeck: deck))
            else { return }
            setS4Pot(action, deck: deck, value: value)
        }

        private func setS4Pot(_ action: ControllerAction, deck: DeckID, value: Double) {
            if action == .filterA || action == .filterB, abs(value - 0.5) > 0.005,
                playbackSnapshot?[deck].mixer.filterEnabled != true
            {
                _ = submitMixer(.filterEnabled, value: 1, deck: deck)
            }
            applyController(action, value: value, refreshMixer: false, targetDeck: deck)
        }

        func primeS4Mixer(_ deck: DeckID) {
            if nativePrimedMixer.insert(deck).inserted {
                for (action, value) in s4Performance.extraPots[deck, default: [:]]
                where action != .tempoA && action != .tempoB {
                    setS4Pot(action, deck: deck, value: value)
                }
            }
            if s4Performance.fx.contains(where: { $0.decks.contains(deck) }) { applyS4FX(deck) }
        }

        private func markS4Loop(_ deck: DeckID, end: Bool) {
            guard let state = playbackSnapshot?[deck], state.generation != 0 else { return }
            let frame = s4Performance.snap ? snappedFrame(state.sourceFrame, deck: deck) : state.sourceFrame
            if !end {
                s4Performance.loopIn[deck] = (state.generation, frame)
            } else if let start = s4Performance.loopIn[deck], start.generation == state.generation, frame > start.frame
            {
                s4Performance.loopRecall[deck] = (state.generation, start.frame, frame)
                setLoop(start: start.frame, end: frame, deck: deck)
            }
        }

        private func applyS4FX(_ deck: DeckID, slot changed: Int? = nil) {
            guard deck.transportIndex < 2 || playback.generations[deck] != nil else { return }
            let assigned = s4Performance.fx.filter { $0.decks.contains(deck) }
            if assigned.isEmpty {
                if let previous = s4Performance.previousFX.removeValue(forKey: deck) {
                    for (slot, effect) in previous.enumerated() { setEffect(effect, slot: slot, deck: deck) }
                }
                return
            }
            let previous =
                s4Performance.previousFX[deck]
                ?? (0..<3).map {
                    effects[deck]?[$0] ?? .init(kind: $0)
                }
            s4Performance.previousFX[deck] = previous
            for slot in 0..<3 where changed == nil || changed == slot {
                var effect = previous[slot]
                if let unit = assigned.first(where: { $0.enabled && $0.slots.contains(slot) }) {
                    effect.x = unit.knobs[slot + 1]
                    effect.y = unit.knobs[0]
                    effect.enabled = true
                } else {
                    effect.enabled = false
                }
                let current = effects[deck]?[slot]
                if current?.enabled != effect.enabled || current?.x != effect.x || current?.y != effect.y
                    || current?.kind != effect.kind
                {
                    setEffect(effect, slot: slot, deck: deck)
                }
            }
        }

        func maintainS4Input() {
            guard s4Connection?.isReceiving == true else { return }
            guard playback.automaticOutputDevice == "S4 Mk2" else {
                s4Performance.inputTask?.cancel()
                s4Performance.inputTask = nil
                s4Performance.inputAttempted = false
                return
            }
            guard !s4Performance.inputAttempted, s4Performance.inputTask == nil,
                playbackSnapshot?.anyDeckActive != true, preparingTrack.isEmpty,
                playback.canOpenCapture(device: "S4 Mk2")
            else { return }
            s4Performance.inputAttempted = true
            s4Performance.inputTask = Task { [weak self] in
                guard let self else { return }
                defer {
                    if !Task.isCancelled { s4Performance.inputTask = nil }
                }
                let permission = AVAudioApplication.shared.recordPermission
                let granted: Bool
                switch permission {
                case .granted: granted = true
                case .undetermined: granted = await AVAudioApplication.requestRecordPermission()
                default: granted = false
                }
                guard !Task.isCancelled else { return }
                guard granted else {
                    s4Status = "S4 Mk2 controls connected. Microphone permission is off."
                    return
                }
                let core = playback.core
                do {
                    try await Task.detached(priority: .utility) { try core.prepareExtraDecks() }.value
                    guard !Task.isCancelled, s4Connection?.isReceiving == true,
                        playback.automaticOutputDevice == "S4 Mk2"
                    else { return }
                    guard preparingTrack.isEmpty, playback.canOpenCapture(device: "S4 Mk2") else {
                        s4Performance.inputAttempted = false
                        return
                    }
                    cancelNativeMusicAnalysis()
                    try playback.setCaptureEnabled(true, device: "S4 Mk2")
                    for deck in [DeckID.c, .d] where playback.generations[deck] == nil {
                        for (action, value) in s4Performance.extraPots[deck, default: [:]]
                        where action != .tempoA && action != .tempoB {
                            setS4Pot(action, deck: deck, value: value)
                        }
                    }
                    s4Status =
                        playback.s4InputChannels == 6
                        ? "S4 Mk2 controls, line inputs and microphone connected."
                        : "S4 Mk2 controls and line inputs connected."
                } catch {
                    guard !Task.isCancelled else { return }
                    s4Status = error.localizedDescription
                }
            }
        }

        func refreshS4Lights() {
            guard let connection = s4Connection, connection.isReceiving, let snapshot = playbackSnapshot else { return }
            var feedback = S4MK2Lights.Feedback()
            feedback.quantize = s4Performance.quantize
            feedback.preview = s4Performance.ownsPreview && s3PreviewHeld && playback.core.previewGeneration != 0
            feedback.recording = isRecording
            feedback.samples = playback.core.playingPads
            feedback.sampleSlots = Set(s2SampleSlots.keys)
            feedback.fxDecks = s4Performance.fx.map(\.decks)
            feedback.fxActive = s4Performance.fx.map(\.enabled)
            feedback.fxSlots = s4Performance.fx.map(\.slots)
            let master = playback.core.masterMeter
            feedback.master = (master.clipLeft, master.clipRight)
            for deck in s4Controls.layers {
                if let contact = s4Performance.slices[deck],
                    contact.generation != snapshot[deck].generation
                        || (contact.bank.looping && !snapshot[deck].loopEnabled)
                {
                    endS4SliceMode(deck)
                }
                if let contact = s4Performance.slices[deck], contact.generation == snapshot[deck].generation {
                    feedback.sliceModes[deck] = contact.bank.looping
                    feedback.heldSlices[deck] = contact.held.last
                }
                feedback.cueHeld[deck] = s4Performance.cueContacts[deck]?.generation == snapshot[deck].generation
                feedback.frames[deck] = playback.core.asset(generation: snapshot[deck].generation)?.frames
                if let track = loaded[deck], let cues = performance.cues[track] {
                    feedback.cues[deck] = Set(cues.keys)
                }
                feedback.loops[deck] = performance.loopBeats(for: deck)
                feedback.loopMarked[deck] = s4Performance.loopIn[deck]?.generation == snapshot[deck].generation
            }
            connection.send(S4MK2Lights.report(snapshot: snapshot, controls: s4Controls, feedback: feedback))
        }
    }
#endif
