#if os(iOS)
    import TDJCore

    extension ReplicaModel {
        func startS4MK1Bridge() {
            guard s4MK1Bridge == nil else { return }
            resetS4MK1Performance()
            let bridge = TraktorHIDBridgeConnection(.s4MK1)
            bridge.onReport = { [weak self] report in
                guard let self else { return }
                let snapshot = playbackSnapshot
                let events = s4MK1Controls.consume(report) {
                    snapshot?[$0].loopEnabled == true && snapshot?[$0].loopRolling != true
                }
                for event in events { applyS4MK1Event(event) }
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
            case .preview:
                if s4MK1Performance.ownsPreview && s3PreviewHeld {
                    stopS3Preview()
                    s4MK1Performance.ownsPreview = false
                } else if automaticOutputDevice == "S4 Mk1 Bridge" {
                    s4MK1Performance.ownsPreview = true
                    applyNativeTraktorEvent(.s3Preview(true), isS3: false)
                }
            case .native(.browser(.move(let detents, _))) where s4MK1Performance.ownsPreview && s3PreviewHeld:
                seekS3Preview(detents: detents)
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
            case .native(.loopTrim(let deck, let end, let ticks)):
                queueS2MK1LoopTrim(deck: deck, end: end, ticks: ticks, stateKey: \.s4MK1LoopTrims)
            case .browseMode(let browsing):
                if browsing { showLibrary(fullyExpanded: true) } else { browserVisible = false }
            case .copyTarget(let target):
                copyS4MK1(target)
            case .copyEnd:
                s4MK1CopySource = nil
            case .clockMaster(let deck):
                selectS4MK1Clock(deck)
            case .loopRecorder(let action):
                handleS4MK1Recorder(action)
            case .micLevel(let level):
                if automaticOutputDevice == "S4 Mk1 Bridge" { playback.core.setS4MicLevel(level) }
            case .tempoReset(let deck) where playbackSnapshot?[deck].synced == true || loaded[deck] == nil:
                s4MK1Controls.unlockTempo(deck)
            case .tempoPickup(let deck, _) where playbackSnapshot?[deck].synced == true || loaded[deck] == nil:
                break
            case .pot(.tempoA, let deck, _), .pot(.tempoB, let deck, _):
                if playbackSnapshot?[deck].synced != true || s4MK1ClockDeck?.deck == deck {
                    applyNativeMK2Event(event, stateKey: \.s4MK1Performance)
                }
            default:
                applyNativeMK2Event(event, stateKey: \.s4MK1Performance)
            }
        }

        private func copyS4MK1(_ target: S4MK1CopyTarget) {
            if let source = s4MK1CopySource {
                s4MK1CopySource = nil
                switch (source, target) {
                case (.deck(let from), .deck(let to)):
                    cloneTrackDeck(from: from, to: to)
                case (.sample(let from), .sample(let to)):
                    guard from != to, s2SampleSlots[to] == nil, let generation = s2SampleSlots[from],
                        let asset = playback.core.asset(generation: generation)
                    else { return }
                    do { s2SampleSlots[to] = try playback.installPad(asset, slot: to) } catch {
                        status = error.localizedDescription
                    }
                case (.recordedLoop, .sample(let to)):
                    copyS4MK1RecordedLoop(to: to)
                default:
                    break
                }
            } else {
                switch target {
                case .deck(let deck) where loaded[deck] != nil: s4MK1CopySource = target
                case .sample(let slot) where s2SampleSlots[slot] != nil: s4MK1CopySource = target
                case .recordedLoop where playback.core.loopRecorderState.contains(.stored): s4MK1CopySource = target
                default: break
                }
            }
        }

        private func copyS4MK1RecordedLoop(to slot: Int) {
            guard s4MK1ExportTask == nil, s2SampleSlots[slot] == nil else { return }
            let core = playback.core
            s4MK1ExportTask = Task { [weak self] in
                guard let self else { return }
                defer { s4MK1ExportTask = nil }
                do {
                    try core.requestLoopRecorderExport()
                    defer { core.finishLoopRecorderExport() }
                    for _ in 0..<100 where core.loopRecorderExportFrames == 0 {
                        if !playback.outputActive { core.processControlsWhileIdle() }
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    guard core.loopRecorderExportFrames > 0 else { throw TransportError.unresolved }
                    let asset = try await Task.detached(priority: .utility) { try core.makeLoopRecorderAsset() }.value
                    try Task.checkCancellation()
                    guard s4MK1Bridge?.isReceiving == true, s2SampleSlots[slot] == nil else { return }
                    s2SampleSlots[slot] = try playback.installPad(asset, slot: slot)
                } catch is CancellationError {
                } catch { status = error.localizedDescription }
            }
        }

        private func selectS4MK1Clock(_ deck: DeckID?) {
            guard let snapshot = playbackSnapshot else { return }
            do {
                if let deck {
                    let state = snapshot[deck]
                    guard state.generation != 0, state.timing != nil else { throw TransportError.unresolved }
                    let bpm = state.synced ? snapshot.masterBPM : state.sourceBPM * state.freeRate
                    try playback.setControllerClock(bpm, reference: deck)
                    s4MK1ClockDeck = (deck, state.generation)
                    s4MK1ReferenceBPM = bpm
                } else {
                    try playback.setControllerClock(snapshot.masterBPM)
                    s4MK1ClockDeck = nil
                }
            } catch { status = error.localizedDescription }
        }

        private func updateS4MK1Clock(_ snapshot: PlaybackSnapshot) {
            guard let clock = s4MK1ClockDeck else { return }
            let state = snapshot[clock.deck]
            guard state.generation == clock.generation, state.timing != nil else {
                s4MK1ClockDeck = nil
                return
            }
            let bpm = state.sourceBPM * state.freeRate
            if !state.synced, abs(bpm - s4MK1ReferenceBPM) >= 0.05 {
                do {
                    try playback.setControllerClock(bpm)
                    s4MK1ReferenceBPM = bpm
                } catch { status = error.localizedDescription }
            }
        }

        private func handleS4MK1Recorder(_ action: PerformanceLoopRecorderAction) {
            guard automaticOutputDevice == "S4 Mk1 Bridge" else { return }
            guard s4MK1RecorderReady else {
                if case .wet = action { return }
                if s4MK1PendingRecorder.count < 8 { s4MK1PendingRecorder.append(action) }
                prepareS4MK1Recorder()
                return
            }
            do {
                if action == .record || action == .play { cancelNativeMusicAnalysis() }
                try playback.controlS4MK1LoopRecorder(action)
            } catch { status = error.localizedDescription }
        }

        private func prepareS4MK1Recorder() {
            guard !s4MK1RecorderReady, s4MK1RecorderTask == nil else { return }
            let core = playback.core
            s4MK1RecorderTask = Task { [weak self] in
                guard let self else { return }
                defer { if !Task.isCancelled { s4MK1RecorderTask = nil } }
                do {
                    try await Task.detached(priority: .utility) { try core.prepareLoopRecorder() }.value
                    guard !Task.isCancelled, s4MK1Bridge?.isReceiving == true,
                        automaticOutputDevice == "S4 Mk1 Bridge"
                    else { return }
                    core.enableLoopRecorder(true)
                    s4MK1RecorderReady = true
                    let commands = s4MK1PendingRecorder
                    s4MK1PendingRecorder.removeAll()
                    if let wet = s4MK1Controls.recorderWet { handleS4MK1Recorder(.wet(wet)) }
                    for command in commands { handleS4MK1Recorder(command) }
                } catch {
                    guard !Task.isCancelled else { return }
                    s4MK1PendingRecorder.removeAll()
                    status = error.localizedDescription
                }
            }
        }

        private func releaseS4MK1Recorder() {
            if s4MK1RecorderReady { playback.core.enableLoopRecorder(false) }
            s4MK1RecorderReady = false
            s4MK1RecorderTask?.cancel()
            s4MK1ExportTask?.cancel()
            s4MK1RecorderTask = nil
            s4MK1PendingRecorder.removeAll()
        }

        private func resetS4MK1Performance() {
            s4MK1Performance = .init()
            for unit in s4MK1Performance.fx.indices {
                s4MK1Performance.fx[unit].mk1 = .init(single: unit)
                s4MK1Performance.fx[unit].enabled = false
            }
        }

        private func releaseS4MK1Bridge() {
            s4MK1Receiving = false
            s4MK1InputStatus = nil
            s4MK1Performance.inputTask?.cancel()
            try? playback.setCaptureEnabled(false, device: "S4 Mk1 Bridge")
            releaseS4MK1Recorder()
            s4MK1ClockDeck = nil
            s4MK1CopySource = nil
            s4MK1LoopTrims.removeAll()
            if s4MK1Performance.ownsPreview { stopS3Preview() }
            for deck in s4MK1Controls.touched {
                applyTraktorDeckAction(deck.leftSide ? .jogTouchA : .jogTouchB, deck: deck, value: 0, quantized: false)
            }
            for deck in s4MK1Controls.bent { resetControllerWheelJog(deck) }
            for deck in DeckID.allCases { releaseS4PerformanceContacts(deck, stateKey: \.s4MK1Performance) }
            for (deck, effects) in s4MK1Performance.previousFX where playback.generations[deck] != nil {
                for (slot, effect) in effects.enumerated() { setEffect(effect, slot: slot, deck: deck) }
            }
            s4MK1Controls = .init()
            resetS4MK1Performance()
        }

        func maintainS4MK1Bridge() {
            guard let bridge = s4MK1Bridge else { return }
            bridge.poll()
            if s4MK1Receiving != bridge.isReceiving { s4MK1Receiving = bridge.isReceiving }
            guard bridge.isReceiving else { return }
            maintainS4Input(device: "S4 Mk1 Bridge", stateKey: \.s4MK1Performance)
            if automaticOutputDevice == "S4 Mk1 Bridge" {
                if playbackSnapshot?.anyDeckActive != true && preparingTrack.isEmpty { prepareS4MK1Recorder() }
            } else if s4MK1RecorderReady || s4MK1RecorderTask != nil {
                releaseS4MK1Recorder()
            }
            flushS2MK1LoopTrims(stateKey: \.s4MK1LoopTrims)
            guard let snapshot = playbackSnapshot else { return }
            updateS4MK1Clock(snapshot)
            if !browserVisible { s4MK1Controls.leaveBrowse() }

            if s4MK1Performance.ownsPreview && automaticOutputDevice != "S4 Mk1 Bridge" {
                stopS3Preview()
                s4MK1Performance.ownsPreview = false
            }

            var feedback = S4MK2Lights.Feedback()
            feedback.lighting = lightOptions(for: "S4 Mk1")
            feedback.preview = s4MK1Performance.ownsPreview && s3PreviewHeld && playback.core.previewGeneration != 0
            feedback.quantize = s4MK1Performance.quantize
            feedback.samples = playback.core.playingPads
            feedback.sampleSlots = Set(s2SampleSlots.keys)
            feedback.fxDecks = s4MK1Performance.fx.map(\.decks)
            feedback.fxActive = s4MK1Performance.fx.map { $0.mk1?.group == false && $0.enabled }
            feedback.fxSlots = s4MK1Performance.fx.map {
                $0.mk1?.group == false ? ($0.mk1?.parameterButtons ?? []) : $0.slots
            }
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
                    snap: s4MK1Performance.snap, browsing: browserVisible, tempo: tempo,
                    clockDeck: s4MK1ClockDeck?.deck, recorder: playback.core.loopRecorderState,
                    fxGroups: s4MK1Performance.fx.map { $0.mk1?.group == true },
                    copySource: s4MK1CopySource))
        }
    }
#endif
