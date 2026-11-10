#if os(iOS)
    import Foundation
    import TDJCore

    struct S4MK2SliceContact {
        let generation: UInt64
        var bank: S4MK2SliceBank
        var held: [Int] = []
        let ownsFreeze: Bool
    }

    struct S4MK2CueContact {
        let generation: UInt64
        let frame: Double
    }

    extension ReplicaModel {
        func toggleS4SliceMode(
            _ deck: DeckID, stateKey: ReferenceWritableKeyPath<ReplicaModel, S4MK2Performance> = \.s4Performance
        ) {
            if self[keyPath: stateKey].slices[deck] != nil {
                endS4SliceMode(deck, stateKey: stateKey)
                return
            }
            guard !editing.contains(deck), !preparingTrack.contains(deck), !arrangementPlaybackActive,
                self[keyPath: stateKey].cueContacts[deck] == nil,
                let state = playbackSnapshot?[deck], !state.touchActive, !state.loopRolling,
                let bank = makeS4SliceBank(deck, state: state, count: self[keyPath: stateKey].sliceCount)
            else { return }
            let ownsFreeze = !frozen.contains(deck)
            self[keyPath: stateKey].slices[deck] = .init(
                generation: state.generation, bank: bank, ownsFreeze: ownsFreeze)
            if ownsFreeze { frozen.insert(deck) }
            viewport[deck] = bank.timing.frame(atBeat: bank.origin + bank.beats / 2)
        }

        private func makeS4SliceBank(_ deck: DeckID, state: DeckPlaybackSnapshot, count: Int) -> S4MK2SliceBank? {
            guard let grid = state.timing, let asset = playback.core.asset(generation: state.generation) else {
                return nil
            }
            if state.loopEnabled {
                let origin = grid.beat(atFrame: state.loopStart)
                return .init(
                    timing: grid, origin: origin, beats: grid.beat(atFrame: state.loopEnd) - origin,
                    frames: Double(asset.frames), looping: true, count: count)
            }
            let visibleBeats = min(32, max(0.25, waveformZoomSeconds(deck: deck) * state.sourceBPM / 60))
            let center = grid.beat(atFrame: viewport[deck] ?? state.sourceFrame)
            return .init(
                timing: grid, origin: floor(center - visibleBeats / 2), beats: visibleBeats,
                frames: Double(asset.frames), looping: false, count: count)
        }

        func moveS4SliceBank(
            _ deck: DeckID, detents: Int, resize: Bool,
            stateKey: ReferenceWritableKeyPath<ReplicaModel, S4MK2Performance> = \.s4Performance
        ) -> Bool {
            guard var contact = self[keyPath: stateKey].slices[deck] else { return false }
            if contact.bank.looping {
                guard !resize else { return false }
                moveS3Loop(deck: deck, beats: Double(detents) * contact.bank.beats)
                return true
            }
            let next = resize ? contact.bank.resized(by: detents) : contact.bank.moved(groups: detents)
            if let next {
                contact.bank = next
                self[keyPath: stateKey].slices[deck] = contact
                viewport[deck] = next.timing.frame(atBeat: next.origin + next.beats / 2)
            }
            return true
        }

        func handleS4Pad(
            _ deck: DeckID, slot: Int, held: Bool, shifted: Bool,
            stateKey: ReferenceWritableKeyPath<ReplicaModel, S4MK2Performance> = \.s4Performance
        ) {
            guard self[keyPath: stateKey].cueContacts[deck] == nil else { return }
            guard var contact = self[keyPath: stateKey].slices[deck] else {
                if held {
                    if slot < 4 {
                        let adding = loaded[deck].map { performance.cues[$0]?[slot] == nil } ?? false
                        cue(
                            slot: slot, deck: deck, delete: shifted,
                            quantized: adding ? self[keyPath: stateKey].snap : self[keyPath: stateKey].quantize)
                    } else {
                        pressS2Sample(slot: (deck.leftSide ? 0 : 8) + slot - 4, shifted: shifted)
                    }
                }
                return
            }
            guard let state = playbackSnapshot?[deck], state.generation == contact.generation else {
                endS4SliceMode(deck, stateKey: stateKey)
                return
            }
            let previous = contact.held.last
            if held {
                contact.held.removeAll { $0 == slot }
                contact.held.append(slot)
            } else {
                contact.held.removeAll { $0 == slot }
            }
            if contact.bank.looping {
                guard state.loopEnabled,
                    let bank = makeS4SliceBank(deck, state: state, count: self[keyPath: stateKey].sliceCount)
                else {
                    endS4SliceMode(deck, stateKey: stateKey)
                    return
                }
                contact.bank = bank
            }
            self[keyPath: stateKey].slices[deck] = contact
            guard previous != contact.held.last else { return }
            if let selected = contact.held.last, let range = contact.bank.range(slot: selected) {
                perform(
                    .touch, deck: deck, value: range.lowerBound, end: contact.bank.looping ? range.upperBound : 0,
                    touchRate: 1, followsPosition: !contact.bank.looping)
            } else if previous != nil {
                perform(.touch, deck: deck, enabled: false)
            }
        }

        func endS4SliceMode(
            _ deck: DeckID, stateKey: ReferenceWritableKeyPath<ReplicaModel, S4MK2Performance> = \.s4Performance
        ) {
            guard let contact = self[keyPath: stateKey].slices.removeValue(forKey: deck) else { return }
            if contact.ownsFreeze {
                frozen.remove(deck)
                previewing.remove(deck)
            }
            if !contact.held.isEmpty, playback.generations[deck] == contact.generation {
                perform(.touch, deck: deck, enabled: false)
            }
        }

        func pressS4Cue(
            _ deck: DeckID, stateKey: ReferenceWritableKeyPath<ReplicaModel, S4MK2Performance> = \.s4Performance,
            recallStored: Bool = false
        ) {
            endS4SliceMode(deck, stateKey: stateKey)
            guard !preparingTrack.contains(deck), !editing.contains(deck), !arrangementPlaybackActive,
                let state = playback.core.snapshot()?[deck], !state.loopRolling, !state.braking,
                playback.generations[deck] == state.generation,
                let asset = playback.core.asset(generation: state.generation), asset.frames > 0
            else { return }

            if state.phase.active {
                let saved = self[keyPath: stateKey].cueMarks[deck]
                let frame = saved?.generation == state.generation ? saved?.frame ?? 0 : cuePoints[deck] ?? 0
                let cue = S4MK2CueContact(generation: state.generation, frame: min(Double(asset.frames - 1), frame))
                self[keyPath: stateKey].cueMarks[deck] = cue
                finishS4Cue(cue, deck: deck, continuePlaying: false)
                return
            }

            let upper = Double(asset.frames)
            let origin = recallStored ? cuePoints[deck] ?? 0 : state.sourceFrame
            let source = min(upper - 1, max(0, origin))
            let savedFrame =
                state.synced
                ? state.timing?.nearestPhaseAlignedFrame(to: source, masterBeat: 0, within: 0..<upper) : nil
            let cue = S4MK2CueContact(generation: state.generation, frame: savedFrame ?? source)
            self[keyPath: stateKey].cueMarks[deck] = cue
            cuePoints[deck] = cue.frame
            let phase = playbackSnapshot?.masterBeat ?? 0
            let aligned =
                state.synced
                ? state.timing?.nearestPhaseAlignedFrame(to: cue.frame, masterBeat: phase, within: 0..<upper) : nil
            cancelCloudSyncForPlayback()
            do {
                try playback.perform(
                    .touch, deck: deck, value: aligned ?? cue.frame, touchRate: 1, followsPosition: true)
                self[keyPath: stateKey].cueContacts[deck] = cue
                refreshPlayback()
            } catch { status = error.localizedDescription }
        }

        func finishS4Cue(
            _ deck: DeckID, continuePlaying: Bool,
            stateKey: ReferenceWritableKeyPath<ReplicaModel, S4MK2Performance> = \.s4Performance
        ) {
            guard let cue = self[keyPath: stateKey].cueContacts.removeValue(forKey: deck) else { return }
            finishS4Cue(cue, deck: deck, continuePlaying: continuePlaying)
        }

        private func finishS4Cue(_ cue: S4MK2CueContact, deck: DeckID, continuePlaying: Bool) {
            do {
                try playback.finishCueContact(
                    deck: deck, generation: cue.generation, cue: cue.frame, continuePlaying: continuePlaying)
                refreshPlayback()
            } catch {
                if continuePlaying {
                    try? playback.finishCueContact(
                        deck: deck, generation: cue.generation, cue: cue.frame, continuePlaying: false)
                }
                status = error.localizedDescription
            }
        }

        func releaseS4PerformanceContacts(
            _ deck: DeckID, stateKey: ReferenceWritableKeyPath<ReplicaModel, S4MK2Performance> = \.s4Performance
        ) {
            finishS4Cue(deck, continuePlaying: false, stateKey: stateKey)
            endS4SliceMode(deck, stateKey: stateKey)
        }
    }
#endif
