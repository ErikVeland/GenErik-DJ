#if os(iOS)
    import TDJCore

    extension ReplicaModel {
        func startTraktorModularBridges() {
            guard z1MK2Bridge == nil, x1MK3Bridge == nil else { return }
            let mixer = TraktorHIDBridgeConnection(.z1MK2)
            mixer.onReport = { [weak self] report in
                guard let self else { return }
                for event in z1MK2Controls.consume(report) { applyZ1MK2(event) }
            }
            mixer.onDisconnect = { [weak self] in
                self?.z1MK2Controls.disconnect()
                self?.z1MK2Takeover.removeAll()
            }
            z1MK2Bridge = mixer
            mixer.start()

            let transport = TraktorHIDBridgeConnection(.x1MK3)
            transport.onReport = { [weak self] report in
                guard let self else { return }
                for event in x1MK3Controls.consume(report) { applyX1MK3(event) }
            }
            transport.onDisconnect = { [weak self] in self?.releaseX1MK3() }
            x1MK3Bridge = transport
            transport.start()
        }

        private func applyZ1MK2(_ event: Z1MK2Controls.Event) {
            switch event {
            case .layer:
                for deck in DeckID.allCases { z1MK2Takeover[deck] = nil }
            case .cue(let deck):
                applyController(deck.leftSide ? .cueA : .cueB, value: 1, refreshMixer: false, targetDeck: deck)
            case .pot(let action, let deck, let value):
                if action == .master || action == .monitor {
                    if automaticOutputDevice == "Z1 Mk2" || automaticOutputDevice == "Z1 Mk2 Bridge" { return }
                }
                let filter = action == .filterA || action == .filterB
                let current = controllerValue(action, targetDeck: deck)
                let target = filter ? s2FXAmount[deck] ?? current : current
                guard
                    z1MK2Takeover[deck, default: [:]][action, default: .init()].shouldApply(
                        input: value, target: target)
                else { return }
                if filter {
                    selectS2FX(z1MK2Controls.choice, deck: deck, enabled: z1MK2FXEnabled.contains(deck))
                    applyS2FXAmount(value, deck: deck, enabled: z1MK2FXEnabled.contains(deck))
                } else {
                    applyController(action, value: value, refreshMixer: false, targetDeck: deck)
                }
            case .fxToggle(let deck):
                if z1MK2FXEnabled.remove(deck) == nil { z1MK2FXEnabled.insert(deck) }
                let enabled = z1MK2FXEnabled.contains(deck)
                selectS2FX(z1MK2Controls.choice, deck: deck, enabled: enabled)
                applyS2FXAmount(s2FXAmount[deck] ?? 0.5, deck: deck, enabled: enabled)
            case .fxSelect(let choice):
                for deck in z1MK2Controls.decks {
                    selectS2FX(choice, deck: deck, enabled: z1MK2FXEnabled.contains(deck))
                }
            }
        }

        private func applyX1MK3(_ event: X1MK3Controls.Event) {
            switch event {
            case .action(let action, let deck):
                let event: S4MK2Event =
                    action == .playA || action == .playB ? .cueLatch(deck) : .action(action, deck, 1)
                applyNativeMK2Event(event, stateKey: \.x1MK3Performance)
            case .cue(let deck, let held):
                applyNativeMK2Event(.cue(deck, held: held), stateKey: \.x1MK3Performance)
            case .reverse(let deck, let held):
                applyNativeTraktorEvent(.reverse(deck, held), isS3: false)
            case .nudge(let deck, let direction, let shifted):
                if shifted {
                    beatJump(beats: Double(direction) * performance.loopBeats(for: deck), deck: deck)
                } else if !x1MK3Controls.reversing.contains(deck) {
                    applyController(
                        deck.leftSide ? .wheelJogA : .wheelJogB,
                        value: direction < 0 ? 0 : 1, targetDeck: deck)
                }
            case .hotcue(let deck, let slot, let delete):
                cue(slot: slot, deck: deck, delete: delete, quantized: true)
            case .loopSize(let deck, let detents, let shifted):
                applyNativeMK2Event(.native(.loopSize(deck, detents, shifted: shifted)), stateKey: \.x1MK3Performance)
            case .browse(let count, let groups):
                queueS2Browser(.move(count, groups: groups))
            case .load(let deck):
                queueS2Browser(.load(deck))
            case .browserView:
                applyNativeTraktorEvent(.browserView, isS3: false)
            case .fxAssign(let unit, let deck):
                if x1Patterns[unit].mode == 2 {
                    if x1Patterns[unit].decks.remove(deck) == nil { x1Patterns[unit].decks.insert(deck) }
                    updateX1Pattern(unit)
                } else { applyNativeMK2Event(.fxAssign(unit, deck), stateKey: \.x1MK3Performance) }
            case .fxEnable(let unit, let slot):
                if x1Patterns[unit].button(slot.map { $0 + 1 } ?? 0, shifted: x1MK3Controls.shifted) {
                    if slot == nil, x1MK3Controls.shifted, x1Patterns[unit].mode == 2 {
                        x1Patterns[unit].decks = x1MK3Performance.fx[unit].decks
                    }
                    updateX1Pattern(unit)
                } else { applyNativeMK2Event(.fxEnable(unit, slot), stateKey: \.x1MK3Performance) }
            case .fxPot(let unit, let knob, let value):
                if x1Patterns[unit].mode == 2 {
                    x1Patterns[unit].knob(knob, value: value)
                    updateX1Pattern(unit)
                } else { applyNativeMK2Event(.fxPot(unit, knob, value), stateKey: \.x1MK3Performance) }
            }
        }

        private func updateX1Pattern(_ unit: Int) {
            playback.core.setPatternUnit(UInt32(unit + 2), settings: x1Patterns[unit].settings)
        }

        private func releaseX1MK3() {
            x1Patterns = [.init(), .init()]
            for unit in 0..<2 { updateX1Pattern(unit) }
            for deck in x1MK3Controls.reversing { perform(.rate, deck: deck, value: 1) }
            for deck in DeckID.allCases {
                releaseS4PerformanceContacts(deck, stateKey: \.x1MK3Performance)
            }
            for (deck, previous) in x1MK3Performance.previousFX where playback.generations[deck] != nil {
                for (slot, effect) in previous.enumerated() { setEffect(effect, slot: slot, deck: deck) }
            }
            x1MK3Controls = .init()
            x1MK3Performance = .init()
        }

        func maintainTraktorModularBridges() {
            z1MK2Bridge?.poll()
            x1MK3Bridge?.poll()
            let z1Receiving = z1MK2Bridge?.isReceiving == true
            let x1Receiving = x1MK3Bridge?.isReceiving == true
            if z1MK2Receiving != z1Receiving { z1MK2Receiving = z1Receiving }
            if x1MK3Receiving != x1Receiving { x1MK3Receiving = x1Receiving }
            guard z1Receiving || x1Receiving, let snapshot = playbackSnapshot else { return }
            func frames(_ deck: DeckID) -> UInt64? {
                playback.core.asset(generation: snapshot[deck].generation)?.frames
            }
            if z1Receiving {
                z1MK2Bridge?.feedback(
                    TraktorModularLights.z1(snapshot, controls: z1MK2Controls, frames: frames, enabled: z1MK2FXEnabled,
                        lighting: lightOptions(for: "Z1 Mk2")))
            }
            if x1Receiving {
                var feedback = TraktorModularLights.X1Feedback()
                feedback.fxDecks = x1MK3Performance.fx.map(\.decks)
                feedback.fxEnabled = x1MK3Performance.fx.map(\.enabled)
                feedback.fxSlots = x1MK3Performance.fx.map(\.slots)
                for (unit, pattern) in x1Patterns.enumerated() where pattern.mode == 2 {
                    feedback.fxDecks[unit] = pattern.decks
                    feedback.fxEnabled[unit] = pattern.enabled
                    feedback.fxSlots[unit] = pattern.ducking ? [2] : []
                }
                for deck in x1MK3Controls.decks {
                    if let track = loaded[deck], let cues = performance.cues[track] {
                        feedback.cues[deck] = Set(cues.keys)
                    }
                    if x1MK3Performance.cueContacts[deck]?.generation == snapshot[deck].generation {
                        feedback.cueHeld.insert(deck)
                    }
                }
                x1MK3Bridge?.feedback(
                    TraktorModularLights.x1(snapshot, controls: x1MK3Controls, frames: frames, feedback: feedback,
                        lighting: lightOptions(for: "X1 Mk3")))
            }
        }
    }
#endif
