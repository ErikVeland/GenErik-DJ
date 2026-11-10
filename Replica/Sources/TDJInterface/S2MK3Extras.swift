#if os(iOS)
    import AVFoundation
    import Foundation
    import TDJCore

    struct S2GridContact {
        let generation: UInt64
        let original: BeatGrid
        var preview: BeatGrid
        let anchor: Bool
    }

    extension ReplicaModel {
        func queueS2Browser(_ command: S2BrowserCommand) {
            if !browserVisible { showLibrary(fullyExpanded: true) }
            guard s2BrowserCommands.count < 32 else { return }
            s2BrowserCommands.append(command)
            s2BrowserRevision &+= 1
        }

        func pressS2Sample(slot: Int, shifted: Bool) {
            do {
                if let generation = s2SampleSlots[slot] {
                    let playing = playback.core.playingPads & (1 << slot) != 0
                    if shifted && !playing {
                        _ = try playback.installPad(nil, slot: slot)
                        s2SampleSlots[slot] = nil
                    } else {
                        if !shifted {
                            cancelNativeMusicAnalysis()
                        }
                        try playback.triggerPad(slot, generation: generation, enabled: !shifted)
                    }
                } else if !shifted {
                    queueS2Browser(.sample(slot))
                }
            } catch { status = error.localizedDescription }
        }

        private var s2MayPrepareSample: Bool {
            !isRecording && !recordingFinishing && !arrangementPlaybackActive && !playback.s2MicrophoneActive
                && !playback.s3ExtEnabled && playback.core.previewGeneration == 0 && playback.core.playingPads == 0
                && DeckID.allCases.allSatisfy { !controlDisplay[$0].phase.active && !preparingPlayback.contains($0) }
        }

        func loadS2Sample(_ entry: LibraryBrowserEntry, slot: Int) {
            guard s2SampleLoad == nil, s2SampleSlots[slot] == nil, entry.canLoad else { return }
            guard s2MayPrepareSample else {
                status = "Pause both decks before loading a sample."
                return
            }
            s2SampleLoad = Task { [weak self] in
                guard let self else { return }
                defer { s2SampleLoad = nil }
                do {
                    let url: URL
                    if let item = entry.nativeItem, item.isOnDevice,
                        let source = try await musicLibraryProvider.playbackSource(item)
                    {
                        url = source.url
                    } else if let track = entry.track, track.nativeLibraryOnly != true {
                        url = store.mediaDirectory.appendingPathComponent(track.mediaFilename)
                    } else {
                        throw MusicLibraryError.missingAudio
                    }
                    try Task.checkCancellation()
                    guard s2MayPrepareSample else { return }
                    let worker = Task.detached(priority: .utility) { try await PCMAsset.preparePadClip(url: url) }
                    let asset = try await withTaskCancellationHandler {
                        try await worker.value
                    } onCancel: {
                        worker.cancel()
                    }
                    try Task.checkCancellation()
                    guard s2MayPrepareSample, s2Connection?.isReceiving == true || s3Connection?.isReceiving == true
                    else { return }
                    s2SampleSlots[slot] = try playback.installPad(asset, slot: slot)
                } catch is CancellationError {
                } catch { status = error.localizedDescription }
            }
        }

        func maintainS2Extras() {
            if s2SampleLoad != nil && !s2MayPrepareSample { s2SampleLoad?.cancel() }
        }

        func selectS2FX(_ choice: S2MixerFX, deck: DeckID, enabled: Bool) {
            let previous = s2FX[deck] ?? .filter
            guard choice != previous else { return }
            if let kind = choice.effect {
                let slot =
                    s2FXSlots[deck].flatMap { slot in
                        effects[deck]?[slot]?.locked != true && effects[deck]?[slot]?.kind == previous.effect?.rawValue
                            ? slot : nil
                    } ?? (0..<3).first { effects[deck]?[$0]?.enabled != true && effects[deck]?[$0]?.locked != true }
                guard let slot else {
                    status = "Free an effect slot on deck \(deck.rawValue.uppercased())."
                    return
                }
                var effect = EffectControl()
                effect.kind = kind.rawValue
                guard setEffect(effect, slot: slot, deck: deck) else { return }
                selectedEffectSlots[deck] = slot
                s2FXSlots[deck] = slot
            } else if let slot = s2FXSlots[deck], var effect = effects[deck]?[slot],
                effect.kind == previous.effect?.rawValue, !effect.locked
            {
                effect.enabled = false
                guard setEffect(effect, slot: slot, deck: deck) else { return }
            }
            s2FX[deck] = choice
            if let amount = s2FXAmount[deck] { applyS2FXAmount(amount, deck: deck, enabled: enabled) }
        }

        func applyS2FXAmount(_ value: Double, deck: DeckID, enabled: Bool) {
            s2FXAmount[deck] = value
            let position = enabled ? value * 2 - 1 : 0
            let wet = abs(position) > 0.025 ? abs(position) : 0
            _ = submitMixer(.filterX, value: position, deck: deck)
            if playbackSnapshot?[deck].mixer.filterEnabled != (wet > 0) {
                _ = submitMixer(.filterEnabled, value: wet > 0 ? 1 : 0, deck: deck)
            }
            guard let slot = s2FXSlots[deck], let kind = s2FX[deck]?.effect, var effect = effects[deck]?[slot],
                !effect.locked, effect.kind == kind.rawValue
            else { return }
            effect.y = wet
            effect.enabled = wet > 0
            setEffect(effect, slot: slot, deck: deck)
        }

        func setNativeTraktorRoll(deck: DeckID, held: Bool, quantized: Bool, beats: Double? = nil) {
            if !held {
                guard let generation = s2RollGenerations.removeValue(forKey: deck),
                    playback.generations[deck] == generation
                else { return }
                perform(.loopRoll, deck: deck, enabled: false)
                return
            }
            guard !arrangementPlaybackActive, !preparingTrack.contains(deck),
                let state = playbackSnapshot?[deck], state.phase == .playing, !state.loopEnabled,
                let timing = state.timing, let asset = playback.core.asset(generation: state.generation)
            else { return }
            let position = state.sourceFrame
            let start = quantized ? max(0, timing.frame(atBeat: floor(timing.beat(atFrame: position)))) : position
            let end = min(
                Double(asset.frames), start + timing.span(beats: beats ?? performance.loopBeats(for: deck), from: start)
            )
            guard end - start >= 1 else { return }
            s2RollGenerations[deck] = state.generation
            perform(.loopRoll, deck: deck, value: start, end: end)
        }

        func beginS2Grid(deck: DeckID, anchor: Bool) {
            if !anchor, !arrangementPlaybackActive, !preparingTrack.contains(deck),
                let state = playbackSnapshot?[deck], state.timing != nil
            {
                do {
                    try playback.setGridMetronome(offset: 0, deck: deck, generation: state.generation)
                    s2MetronomeGenerations[deck] = state.generation
                } catch { status = error.localizedDescription }
            }
            if !anchor, playbackSnapshot?[deck].phase.active == true { return }
            guard !arrangementPlaybackActive, let state = playbackSnapshot?[deck], !state.phase.active,
                !state.touchActive,
                !state.loopEnabled, !preparingPlayback.contains(deck), !editing.contains(deck),
                let preparation = gridPreparation(deck), !preparation.gridLocked, let grid = preparation.grid
            else {
                status = "Pause the deck and unlock its grid before editing."
                return
            }
            var draft = grid
            if anchor, let timing = timing(deck) {
                let beat = timing.beat(atFrame: state.sourceFrame).rounded()
                guard beat.isFinite else { return }
                let offset = state.sourceFrame - timing.frame(atBeat: beat)
                guard (try? draft.shiftWaveform(bySourceFrames: -offset)) != nil else { return }
                let index = Int(beat.truncatingRemainder(dividingBy: 4))
                guard (try? draft.selectDownbeat((index + 4) % 4)) != nil else { return }
            }
            s2Grids[deck] = .init(generation: state.generation, original: grid, preview: draft, anchor: anchor)
            editing.insert(deck)
            gridDraft[deck] = draft
        }

        func moveS2Grid(deck: DeckID, ticks: Int) {
            guard var contact = s2Grids[deck], !contact.anchor,
                playbackSnapshot?[deck].generation == contact.generation
            else { return }
            let offset = Double(ticks) * contact.preview.framesPerBeat / 600
            guard (try? contact.preview.shiftWaveform(bySourceFrames: -offset)) != nil else { return }
            s2Grids[deck] = contact
            gridDraft[deck] = contact.preview
            if let generation = s2MetronomeGenerations[deck] {
                try? playback.setGridMetronome(
                    offset: contact.preview.anchorFrame - contact.original.anchorFrame, deck: deck,
                    generation: generation)
            }
        }

        func selectS2GridDownbeat(deck: DeckID, beat: Int) {
            guard var contact = s2Grids[deck], !contact.anchor,
                playbackSnapshot?[deck].generation == contact.generation,
                (try? contact.preview.selectDownbeat(beat)) != nil
            else { return }
            s2Grids[deck] = contact
            gridDraft[deck] = contact.preview
        }

        func endS2Grid(deck: DeckID, save: Bool) {
            if let generation = s2MetronomeGenerations.removeValue(forKey: deck) {
                try? playback.setGridMetronome(offset: nil, deck: deck, generation: generation)
            }
            guard let contact = s2Grids.removeValue(forKey: deck) else { return }
            editing.remove(deck)
            if gridDraft[deck] == contact.preview { gridDraft[deck] = nil }
            guard save, contact.preview != contact.original, let state = playbackSnapshot?[deck],
                state.generation == contact.generation, !state.phase.active,
                gridPreparation(deck)?.grid == contact.original
            else { return }
            saveGrid(contact.preview, deck: deck)
        }

        func toggleS2Mic() {
            if playback.s2MicEnabled {
                try? playback.setS2MicEnabled(false)
                return
            }
            guard automaticOutputDevice == "S2 Mk3" else {
                status = "Connect the S2 Mk3 audio output before using MIC."
                return
            }
            guard s2MicRequest == nil, playback.canOpenS2Mic else {
                status = "Pause both decks before opening the S2 Mk3 microphone."
                return
            }
            s2MicRequest = Task { [weak self] in
                guard let self else { return }
                defer { s2MicRequest = nil }
                let permission = AVAudioApplication.shared.recordPermission
                let granted: Bool
                switch permission {
                case .granted: granted = true
                case .undetermined: granted = await AVAudioApplication.requestRecordPermission()
                default: granted = false
                }
                guard !Task.isCancelled, s2Connection?.isReceiving == true else { return }
                guard granted else {
                    status = "Allow microphone access to use the S2 Mk3 MIC button."
                    return
                }
                cancelNativeMusicAnalysis()
                do { try playback.setS2MicEnabled(true) } catch { status = error.localizedDescription }
            }
        }

        func releaseS2Extras() {
            s2SampleLoad?.cancel()
            s2MicRequest?.cancel()
            try? playback.setS2MicEnabled(false)
            for (slot, generation) in s2SampleSlots {
                try? playback.triggerPad(slot, generation: generation, enabled: false)
            }
            for deck in DeckID.primary { endS2Grid(deck: deck, save: false) }
            s2BrowserCommands.removeAll()
        }
    }
#endif
