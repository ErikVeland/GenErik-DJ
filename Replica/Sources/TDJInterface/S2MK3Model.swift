#if os(iOS)
    import Foundation
    import TDJCore

    extension ReplicaModel {
        func startS2MK3() {
            guard s2Connection == nil else { return }
            let connection = NIControllerAccessoryConnection(model: .s2MK3)
            connection.onState = { [weak self] status, _ in self?.s2Status = status }
            connection.onFrame = { [weak self] frame in self?.receiveS2Frame(frame) }
            connection.onDisconnect = { [weak self] in self?.releaseS2Controls() }
            do {
                try connection.start()
                s2Connection = connection
            } catch { s2Status = error.localizedDescription }
        }

        private func receiveS2Frame(_ frame: Z1AccessoryProtocol.Frame) {
            for event in s2Controls.consume(frame) { applyNativeTraktorEvent(event, isS3: false) }
        }

        func applyNativeTraktorEvent(_ event: NativeTraktorEvent, isS3: Bool) {
            switch event {
            case .action(let action, let value):
                applyTraktorDeckAction(action, deck: action.deck, value: value, quantized: isS3 || s2Quantize)
            case .pot(let action, let value):
                if isS3 {
                    applyS3Pot(action, deck: action.deck, value: value)
                } else {
                    let filter = action == .filterA || action == .filterB
                    let target = filter ? s2FXAmount[action.deck] ?? controllerValue(action) : controllerValue(action)
                    if s2Takeover[action, default: .init()].shouldApply(input: value, target: target) {
                        if filter {
                            applyS2FXAmount(value, deck: action.deck, enabled: true)
                        } else {
                            applyController(action, value: value, refreshMixer: false)
                        }
                    }
                }
            case .deleteCue(let deck, let slot):
                cue(slot: slot, deck: deck, delete: true)
            case .flux(let deck):
                perform(.flux, deck: deck, enabled: playbackSnapshot?[deck].fluxEnabled != true)
            case .reverse(let deck, let held):
                resetControllerWheelJog(deck, restoreRate: false)
                perform(.rate, deck: deck, value: held ? -1 : 1)
            case .browser(let command):
                queueS2Browser(command)
            case .eject(let deck):
                ejectNativeTraktorDeck(deck)
            case .loopRoll(let deck, let held):
                setNativeTraktorRoll(
                    deck: deck, held: held, quantized: isS3 || s2Quantize,
                    beats: isS3 ? s3JumpBeats[deck, default: 4] : nil)
            case .browserOpen:
                if !browserVisible { showLibrary(fullyExpanded: true) }
            case .park(let deck, let atCue):
                guard loaded[deck] != nil, !preparingTrack.contains(deck) else { return }
                if playbackSnapshot?[deck].phase.active == true { pressPlay(deck: deck, vinylStop: false) }
                jump(atCue ? cuePoints[deck] ?? 0 : 0, deck: deck, quantized: false)
            case .browserView:
                if browserVisible && browserPresentationExpands {
                    browserVisible = false
                } else {
                    showLibrary(fullyExpanded: true)
                }
            case .samplePad(let slot, let shifted):
                pressS2Sample(slot: slot, shifted: shifted)
            case .sampleGain(let value):
                do { try playback.setPadGain(value) } catch { status = error.localizedDescription }
            case .fx(let choice, let decks):
                for deck in DeckID.allCases where decks.contains(deck) {
                    if isS3 && deck.transportIndex >= 2 {
                        s3PendingFX[deck] = choice
                        if playback.generations[deck] == nil || (deck == .d && playback.s3ExtEnabled) { continue }
                    }
                    selectS2FX(choice, deck: deck, enabled: !isS3 || s3FXEnabled.contains(deck))
                }
            case .fxToggle(let deck):
                if deck == .d && playback.s3ExtEnabled { return }
                if s3FXEnabled.remove(deck) == nil { s3FXEnabled.insert(deck) }
                if deck.transportIndex < 2 || playback.generations[deck] != nil {
                    applyS2FXAmount(s2FXAmount[deck] ?? 0.5, deck: deck, enabled: s3FXEnabled.contains(deck))
                }
            case .move(let deck, let detents, let shifted):
                moveS3(deck: deck, detents: detents, shifted: shifted)
            case .loopSize(let deck, let detents, let shifted):
                if shifted {
                    moveS3Loop(deck: deck, beats: Double(detents) * s3JumpBeats[deck, default: 4])
                } else {
                    let sizes = PerformancePreparation.loopSizes
                    if let current = sizes.firstIndex(of: performance.loopBeats(for: deck)) {
                        setLoopSize(sizes[min(sizes.count - 1, max(0, current + detents))], deck: deck)
                    }
                }
            case .gridBegin(let deck, let anchor):
                beginS2Grid(deck: deck, anchor: anchor)
            case .gridMove(let deck, let ticks):
                moveS2Grid(deck: deck, ticks: ticks)
            case .gridEnd(let deck):
                endS2Grid(deck: deck, save: true)
            case .mic:
                toggleS2Mic()
            case .quantize:
                s2Quantize.toggle()
            case .s3Layer(let deck):
                s3Takeover[deck]?[deck.leftSide ? .tempoA : .tempoB] = nil
            case .s3BendEnd(let deck):
                resetControllerWheelJog(deck)
            case .s3Action(let action, let deck, let value):
                if deck != .d || !playback.s3ExtEnabled || value == 0 {
                    applyTraktorDeckAction(action, deck: deck, value: value, quantized: true)
                }
            case .s3Pot(let action, let deck, let value):
                applyS3Pot(action, deck: deck, value: value)
            case .s3Preview(let held):
                if held {
                    stopS3Preview()
                    s3PreviewHeld = true
                    queueS2Browser(.previewS3)
                } else {
                    stopS3Preview()
                }
            case .s3PreviewSeek(let detents):
                seekS3Preview(detents: detents)
            case .s3EXT(let shifted):
                toggleS3EXT(shifted: shifted)
            case .s3EXTCue:
                if playback.s3ExtEnabled {
                    s3EXTCue.toggle()
                    updateS3EXTMix()
                } else if playback.generations[.d] != nil {
                    applyController(.cueB, value: 1, targetDeck: .d)
                }
            case .s3EXTLevel(let value, let trim):
                if trim { s3EXTTrim = pow(4, 2 * value - 1) } else { s3EXTLevel = value }
                if playback.s3ExtEnabled { updateS3EXTMix() }
                else { applyS3Pot(trim ? .gainB : .levelB, deck: .d, value: value) }
            }
        }

        private func applyTraktorDeckAction(
            _ action: ControllerAction, deck: DeckID, value: Double, quantized: Bool
        ) {
            if action == .jogA || action == .jogB {
                s2LastScratch[deck] = ProcessInfo.processInfo.systemUptime
            } else if action.isMomentary && value == 0 {
                s2LastScratch[deck] = nil
            }
            if let slot = action.hotcueSlot {
                cue(slot: slot, deck: deck, quantized: quantized)
            } else if action == .loopA || action == .loopB {
                toggleLoop(deck: deck, quantized: quantized)
            } else {
                applyController(action, value: value, targetDeck: deck)
            }
        }

        func settleS2Scratch() {
            guard !s2LastScratch.isEmpty else { return }
            let now = ProcessInfo.processInfo.systemUptime
            for deck in DeckID.allCases {
                guard let last = s2LastScratch[deck], now - last >= 0.06 else { continue }
                s2LastScratch[deck] = nil
                applyController(deck.leftSide ? .jogA : .jogB, value: 0.5, targetDeck: deck)
            }
        }

        private func releaseS2Controls() {
            for deck in s2Controls.touched { applyController(deck == .a ? .jogTouchA : .jogTouchB, value: 0) }
            for deck in s2Controls.reversing { perform(.rate, deck: deck, value: 1) }
            for deck in DeckID.primary { resetControllerWheelJog(deck) }
            for deck in s2Controls.rolling {
                setNativeTraktorRoll(deck: deck, held: false, quantized: s2Quantize)
            }
            releaseS2Extras()
            s2Controls = .init()
            s2Takeover.removeAll()
            for deck in DeckID.primary { s2LastScratch[deck] = nil }
        }

        func refreshS2Lights() {
            guard let connection = s2Connection, connection.isReceiving, let snapshot = playbackSnapshot else { return }
            let frames = (
                a: playback.core.asset(generation: snapshot.a.generation)?.frames,
                b: playback.core.asset(generation: snapshot.b.generation)?.frames
            )
            func slots(_ deck: DeckID) -> Set<Int> {
                guard let track = loaded[deck], let cues = performance.cues[track] else { return [] }
                return Set(cues.keys)
            }
            let feedback = S2MK3Feedback(
                sampleDecks: s2Controls.samples, sampleSlots: Set(s2SampleSlots.keys),
                playingSamples: playback.core.playingPads,
                shifts: s2Controls.shifts, gridDecks: Set(s2Grids.keys),
                fx: Set(DeckID.primary.map { s2FX[$0] ?? .filter }), browser: browserVisible,
                mic: playback.s2MicEnabled, quantize: s2Quantize)
            connection.send(
                S2MK3Lights.report(
                    snapshot: snapshot, sourceFrames: frames, cues: (slots(.a), slots(.b)), feedback: feedback))
        }
    }
#endif
