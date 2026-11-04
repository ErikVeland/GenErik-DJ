import AVFoundation
import SwiftUI
import TDJCore

#if os(iOS)
    import ExternalAccessory
#endif

private enum LearnedControllerProfile: Equatable { case flx4, flx10, rev1, rev5, ddj1000 }

struct ControllerSettingsView: View {
    @Bindable var model: ReplicaModel
    @State private var connections: [String] = []
    @State private var replacingControllerMappings: LearnedControllerProfile?
    @State private var replacingControllerFeedback = false
    @State private var replacingFLX10Feedback = false
    @State private var replacingREV1Feedback = false
    @State private var replacingREV5Feedback = false
    @State private var replacingDDJ1000Feedback = false
    private var input: ControllerMIDIConnection { model.controllerInput }
    private var selectedInputInactive: Bool { input.selected.map { !input.isInputActive($0) } ?? true }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Controllers").font(.headline)
            Toggle("Enable controller input", isOn: Binding(get: { input.enabled }, set: enable))
            Text(input.status).foregroundStyle(.secondary)
            if input.enabled {
                Picker("Input to configure", selection: Binding(get: { input.selected }, set: input.select)) {
                    Text("Choose an input").tag(Int32?.none)
                    ForEach(input.sources) { source in Text(source.name).tag(Optional(source.id)) }
                }
                Text("Active MIDI inputs").font(.subheadline)
                ForEach(input.sources) { source in
                    Toggle(
                        source.name,
                        isOn: Binding(
                            get: { input.isInputActive(source.id) },
                            set: { input.setInputActive(source.id, active: $0) }))
                }
                Button("DDJ-FLX4 MIDI profile") { replacingControllerMappings = .flx4 }.disabled(
                    selectedInputInactive || input.originalZ1Bridge)
                Text(
                    "Maps transport, mixer, Hot Cue pads and platter jog. Wheel-side jog bends playback by up to 8% and resets after 150 ms without input."
                ).font(.caption).foregroundStyle(.secondary)
                Button("DDJ-FLX10 MIDI profile") { replacingControllerMappings = .flx10 }.disabled(
                    selectedInputInactive || input.originalZ1Bridge)
                Text(
                    "Maps the published two-deck controls, loops, Beat Jump, mixer and jog messages. Deck 3/4 and stem controls are not mapped. Set the pads to Hot Cue mode."
                ).font(.caption).foregroundStyle(.secondary)
                Button("DDJ-REV1 MIDI profile") { replacingControllerMappings = .rev1 }.disabled(
                    selectedInputInactive || input.originalZ1Bridge)
                Text(
                    "Maps transport, mixer, loop controls, Hot Cue pads and jog. Set the performance pads to Hot Cue mode."
                ).font(.caption).foregroundStyle(.secondary)
                Button("DDJ-REV5 MIDI profile") { replacingControllerMappings = .rev5 }.disabled(
                    selectedInputInactive || input.originalZ1Bridge)
                Text(
                    "Maps the published two-deck transport, mixer, Hot Cue pads, jog controls and momentary Shift layer. Set both pad banks to Hot Cue mode."
                ).font(.caption).foregroundStyle(.secondary)
                Button("DDJ-1000 MIDI profile") { replacingControllerMappings = .ddj1000 }.disabled(
                    selectedInputInactive || input.originalZ1Bridge)
                Text(
                    "Maps Deck 1/2 transport, mixer, tempo, loop, jog, Shift and Hot Cue controls. Deck 3/4 are not mapped. Set the pads to Hot Cue mode."
                ).font(.caption).foregroundStyle(.secondary)
                Button("Refresh connections") {
                    input.refreshSources()
                    refreshConnections()
                }
                Toggle(
                    "Original Z1 through GenErik bridge",
                    isOn: Binding(get: { input.originalZ1Bridge }, set: input.setBridgeMode))
                if input.originalZ1Bridge {
                    Text(input.bridgeStatus).foregroundStyle(.secondary)
                    Text(input.feedbackStatus).font(.caption).foregroundStyle(.secondary)
                    Picker(
                        "Bridge feedback output",
                        selection: Binding(get: { input.feedbackSelected }, set: input.setFeedbackDestination)
                    ) {
                        Text("No feedback output").tag(Int32?.none)
                        ForEach(input.destinations) { destination in
                            Text(destination.name).tag(Optional(destination.id))
                        }
                    }
                    Text(
                        "Use only with the GenErik Z1 bridge relay. This carries controls and lights, not audio. Direct Z1 accessory communication is separate."
                    ).font(.caption).foregroundStyle(.secondary)
                } else {
                    Picker(
                        "Feedback output",
                        selection: Binding(get: { input.feedbackSelected }, set: input.setFeedbackDestination)
                    ) {
                        Text("Choose an output").tag(Int32?.none)
                        ForEach(input.destinations) { destination in
                            Text(destination.name).tag(Optional(destination.id))
                        }
                    }
                    Button("DDJ-FLX4 LED feedback profile") { replacingControllerFeedback = true }.disabled(
                        input.feedbackSelected == nil
                    ).confirmationDialog(
                        "Replace DDJ-FLX4 LED feedback?", isPresented: $replacingControllerFeedback,
                        titleVisibility: .visible
                    ) {
                        Button("Replace play, sync, headphone-cue and Hot Cue mappings", role: .destructive) {
                            input.applyDDJFLX4FeedbackProfile()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "This updates only the listed status and Hot Cue mappings for the selected MIDI output. Feedback stays off until you enable it."
                        )
                    }
                    Text("Maps play, sync, headphone-cue and Hot Cue lights from the published DDJ-FLX4 MIDI list.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("DDJ-FLX10 LED feedback profile") { replacingFLX10Feedback = true }.disabled(
                        input.feedbackSelected == nil
                    ).confirmationDialog(
                        "Replace DDJ-FLX10 LED feedback?", isPresented: $replacingFLX10Feedback,
                        titleVisibility: .visible
                    ) {
                        Button("Replace play, sync, headphone-cue and Hot Cue mappings", role: .destructive) {
                            input.applyDDJFLX10FeedbackProfile()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "This updates only the listed status and Hot Cue mappings for the selected MIDI output. Feedback stays off until you enable it."
                        )
                    }
                    Text(
                        "Maps play, sync, headphone-cue and Hot Cue lights from the published DDJ-FLX10 MIDI list. Hot Cue lights use one fixed colour."
                    ).font(.caption).foregroundStyle(.secondary)
                    Button("DDJ-1000 LED feedback profile") { replacingDDJ1000Feedback = true }.disabled(
                        input.feedbackSelected == nil
                    ).confirmationDialog(
                        "Replace DDJ-1000 LED feedback?", isPresented: $replacingDDJ1000Feedback,
                        titleVisibility: .visible
                    ) {
                        Button("Replace play, sync, headphone-cue and Hot Cue mappings", role: .destructive) {
                            input.applyDDJ1000FeedbackProfile()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "This updates only the listed status and Hot Cue mappings for the selected MIDI output. Feedback stays off until you enable it."
                        )
                    }
                    Text("Maps play, sync, headphone-cue and Hot Cue lights from the published DDJ-1000 MIDI list.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("DDJ-REV1 LED feedback profile") { replacingREV1Feedback = true }.disabled(
                        input.feedbackSelected == nil
                    ).confirmationDialog(
                        "Replace DDJ-REV1 LED feedback?", isPresented: $replacingREV1Feedback, titleVisibility: .visible
                    ) {
                        Button("Replace play, sync, headphone-cue and Hot Cue mappings", role: .destructive) {
                            input.applyDDJREV1FeedbackProfile()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "This updates only the listed status and Hot Cue mappings for the selected MIDI output. Feedback stays off until you enable it."
                        )
                    }
                    Text("Maps play, sync, headphone-cue and Hot Cue lights from the published DDJ-REV1 MIDI list.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("DDJ-REV5 LED feedback profile") { replacingREV5Feedback = true }.disabled(
                        input.feedbackSelected == nil
                    ).confirmationDialog(
                        "Replace DDJ-REV5 LED feedback?", isPresented: $replacingREV5Feedback, titleVisibility: .visible
                    ) {
                        Button("Replace play, sync, headphone-cue and Hot Cue mappings", role: .destructive) {
                            input.applyDDJREV5FeedbackProfile()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "This updates only the listed status and Hot Cue mappings for the selected MIDI output. Feedback stays off until you enable it."
                        )
                    }
                    Text("Maps play, sync, headphone-cue and Hot Cue lights from the published DDJ-REV5 MIDI list.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle(
                        "Enable generic MIDI feedback",
                        isOn: Binding(get: { input.midiFeedbackEnabled }, set: input.setMIDIFeedbackEnabled)
                    ).disabled(
                        !input.feedbackOutputAvailable || input.feedbackSelected == nil
                            || input.selectedFeedbackBindings.isEmpty)
                    Text(input.feedbackStatus).font(.caption).foregroundStyle(.secondary)
                    ControllerFeedbackSettingsView(input: input)
                    if input.learning != .shift {
                        Picker(
                            "Control encoding",
                            selection: Binding(get: { input.learningEncoding }, set: { input.learningEncoding = $0 })
                        ) {
                            ForEach(ControllerMIDIEncoding.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
                        }
                        Toggle(
                            "Reverse knob / fader direction",
                            isOn: Binding(get: { input.learningInverted }, set: { input.learningInverted = $0 }))
                        Toggle(
                            "Learn in Shift layer",
                            isOn: Binding(get: { input.learningShifted }, set: { input.learningShifted = $0 }))
                        Text("Hold the learned Shift control to use these assignments.").font(.caption).foregroundStyle(
                            .secondary)
                    } else {
                        Text("Move a momentary note or Control Change button to learn Shift.").font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(input.lastInput).font(.caption).foregroundStyle(.secondary)
                    if let action = input.learning {
                        Text("Move the control for \(action.title). Learning does not operate the deck.")
                        Button("Cancel learning") { input.learning = nil }
                    }
                    Text(
                        "Choose the encoding documented for the control. Knob / fader also handles note buttons and pitch-bend faders. Other modes handle paired high-resolution CCs or relative encoders. Generic feedback sends only the output messages configured above."
                    ).font(.caption).foregroundStyle(.secondary)
                    ForEach(ControllerAction.allCases) { action in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(action.title)
                                Text(input.bindingName(action)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(input.learning == action ? "Waiting…" : "Learn") {
                                if action == .shift {
                                    input.learningShifted = false
                                    input.learningEncoding = .absolute
                                    input.learningInverted = false
                                }
                                input.learning = action
                            }.disabled(selectedInputInactive)
                        }
                    }
                    Button("Clear learned controls", role: .destructive) { input.clearBindings() }.disabled(
                        input.bindingCount == 0)
                }
            }
            Divider()
            Text("Z1 connection").font(.headline)
            Text(
                "For the original Z1, MIDI mode uses MODE + both headphone cue buttons. A MIDI mode setting does not guarantee that iPadOS exposes an input."
            ).font(.caption).foregroundStyle(.secondary)
            Text(
                "If the controller has only an accessory or audio connection, its controls need an implemented accessory protocol or the approved hardware bridge."
            ).font(.caption).foregroundStyle(.secondary)
            ForEach(Array(connections.enumerated()), id: \.offset) { _, text in
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
            Button("Refresh connection details") { refreshConnections() }
            ShareLink(
                "Share controller connection details",
                item: ([input.status, input.lastInput] + connections).joined(separator: "\n"))
        }.confirmationDialog(
            "Replace mappings for this input?",
            isPresented: Binding(
                get: { replacingControllerMappings != nil }, set: { if !$0 { replacingControllerMappings = nil } }),
            titleVisibility: .visible
        ) {
            if replacingControllerMappings == .flx4 {
                Button("Replace selected input mappings", role: .destructive) { input.applyDDJFLX4Profile() }
            } else if replacingControllerMappings == .flx10 {
                Button("Replace selected input mappings", role: .destructive) { input.applyDDJFLX10Profile() }
            } else if replacingControllerMappings == .rev1 {
                Button("Replace selected input mappings", role: .destructive) { input.applyDDJREV1Profile() }
            } else if replacingControllerMappings == .rev5 {
                Button("Replace selected input mappings", role: .destructive) { input.applyDDJREV5Profile() }
            } else if replacingControllerMappings == .ddj1000 {
                Button("Replace selected input mappings", role: .destructive) { input.applyDDJ1000Profile() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces mappings for the selected MIDI input only. Mappings for other inputs stay in place.")
        }.onAppear { refreshConnections() }
    }
    private func enable(_ enabled: Bool) {
        if enabled {
            let model = model
            input.onAction = { [weak model] action, value in model?.applyController(action, value: value) }
            input.currentValue = { [weak model] action in model?.controllerValue(action) }
            input.onZ1Report = { [weak model] report in model?.receiveZ1(report) }
            input.onZ1Calibration = { [weak model] calibration in model?.configureZ1Bridge(calibration) }
            input.onBridgeReset = { [weak model] in model?.configureZ1Bridge(nil) }
            input.start()
        } else {
            input.stop()
        }
    }
    private func refreshConnections() {
        #if os(iOS)
            connections = EAAccessoryManager.shared().connectedAccessories.map {
                "Accessory: \($0.name). Protocols: \($0.protocolStrings.joined(separator: ", "))"
            }
            connections += AVAudioSession.sharedInstance().currentRoute.outputs.map { "Audio output: \($0.portName)" }
            if connections.isEmpty { connections = ["No accessory or audio connection reported."] }
        #else
            connections = ["The current controller test target is iPad."]
        #endif
    }
}

extension ReplicaModel {
    func applyControllerWheelJog(_ value: Double, deck: DeckID) {
        guard loaded[deck] != nil else {
            resetControllerWheelJog(deck, restoreRate: false)
            return
        }
        guard playbackSnapshot?[deck].touchActive != true, !controllerJogTouched.contains(deck) else {
            resetControllerWheelJog(deck, restoreRate: false)
            return
        }
        let delta = ControllerJogBend.deltaCounts(fromNormalizedValue: value)
        guard delta != 0 else {
            resetControllerWheelJog(deck)
            return
        }
        let offset = ControllerJogBend.accumulatedCounts(
            current: controllerJogBendOffsets[deck, default: 0], delta: delta)
        controllerJogBendOffsets[deck] = offset
        perform(.rate, deck: deck, value: ControllerJogBend.playbackRate(forCounts: offset))
        controllerJogBendTasks[deck]?.cancel()
        let token = UUID()
        controllerJogBendTokens[deck] = token
        controllerJogBendTasks[deck] = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: ControllerJogBend.releaseDelayNanoseconds) } catch { return }
            guard let self, self.controllerJogBendTokens[deck] == token else { return }
            self.resetControllerWheelJog(deck)
        }
    }

    func resetControllerWheelJog(_ deck: DeckID, restoreRate: Bool = true) {
        let wasActive = controllerJogBendOffsets[deck, default: 0] != 0 || controllerJogBendTasks[deck] != nil
        controllerJogBendTasks[deck]?.cancel()
        controllerJogBendTasks[deck] = nil
        controllerJogBendTokens[deck] = nil
        controllerJogBendOffsets[deck] = 0
        if wasActive, restoreRate, playbackSnapshot?[deck].touchActive != true { perform(.rate, deck: deck, value: 1) }
    }

    func controllerValue(_ action: ControllerAction) -> Double? {
        if let slot = action.hotcueSlot {
            guard let trackID = loaded[action.deck] else { return 0 }
            return performance.cues[trackID]?[slot] == nil ? 0 : 1
        }
        guard let snapshot = playbackSnapshot else { return nil }
        let deck = action.deck
        let mixer = snapshot[deck].mixer
        switch action {
        case .playA, .playB: return snapshot[deck].phase == .playing ? 1 : 0
        case .syncA, .syncB: return snapshot[deck].synced ? 1 : 0
        case .keylockA, .keylockB: return snapshot[deck].keylock ? 1 : 0
        case .cueA, .cueB: return mixer.cue ? 1 : 0
        case .filterToggleA, .filterToggleB: return mixer.filterEnabled ? 1 : 0
        case .loopA, .loopB: return snapshot[deck].loopEnabled ? 1 : 0
        case .fxToggleA, .fxToggleB:
            return effects[deck]?[selectedEffectSlots[deck, default: 0]]?.enabled == true ? 1 : 0
        case .levelA, .levelB: return mixerFaderValue(.volume, deck: deck)
        case .gainA, .gainB: return mixer.gain > 0 ? (log(mixer.gain) / log(4) + 1) / 2 : 0
        case .lowA, .lowB: return mixerFaderValue(.low, deck: deck).map { $0 / 2 }
        case .midA, .midB: return mixerFaderValue(.mid, deck: deck).map { $0 / 2 }
        case .highA, .highB: return mixerFaderValue(.high, deck: deck).map { $0 / 2 }
        case .filterA, .filterB: return (mixer.filterX + 1) / 2
        case .fxA, .fxB: return effects[deck]?[selectedEffectSlots[deck, default: 0]]?.x ?? 0.5
        case .crossfader: return snapshot.crossfader
        case .cueMix: return snapshot.cueBlend
        case .master: return snapshot.masterGain
        case .monitor: return snapshot.monitorGain
        case .tempoA, .tempoB: return min(1, max(0, (deckTempoPercent(deck: deck) + 8) / 16))
        default: return nil
        }
    }
    func applyController(_ action: ControllerAction, value: Double) {
        guard value.isFinite, (0...1).contains(value) else { return }
        let deck = action.deck
        switch action {
        case .playA, .playB: pressPlay(deck: deck)
        case .syncA, .syncB: toggleSync(deck: deck)
        case .keylockA, .keylockB: toggleKeylock(deck: deck)
        case .cueA, .cueB: setMixer(.cue, value: playbackSnapshot?[deck].mixer.cue == true ? 0 : 1, deck: deck)
        case .levelA, .levelB: setMixer(.volume, value: value, deck: deck)
        case .gainA, .gainB: setMixer(.gain, value: pow(4, 2 * value - 1), deck: deck)
        case .lowA, .lowB: setMixer(.low, value: 2 * value, deck: deck)
        case .midA, .midB: setMixer(.mid, value: 2 * value, deck: deck)
        case .highA, .highB: setMixer(.high, value: 2 * value, deck: deck)
        case .filterA, .filterB: setMixer(.filterX, value: 2 * value - 1, deck: deck)
        case .filterToggleA, .filterToggleB:
            setMixer(.filterEnabled, value: playbackSnapshot?[deck].mixer.filterEnabled == true ? 0 : 1, deck: deck)
        case .fxA, .fxB: setHardwareEffectX(value, deck: deck)
        case .fxToggleA, .fxToggleB: toggleHardwareEffect(deck: deck)
        case .crossfader: setMixer(.crossfader, value: value)
        case .cueMix: setMixer(.cueBlend, value: value)
        case .master: setMixer(.master, value: value)
        case .monitor: setMixer(.monitor, value: value)
        case .tempoA, .tempoB: setDeckTempo(percent: value * 16 - 8, deck: deck)
        case .loopA, .loopB: toggleLoop(deck: deck)
        case .loopUpA, .loopUpB: stepLoopSize(direction: 1, deck: deck)
        case .loopDownA, .loopDownB: stepLoopSize(direction: -1, deck: deck)
        case .jumpBackA, .jumpBackB: beatJump(beats: -performance.loopBeats(for: deck), deck: deck)
        case .jumpForwardA, .jumpForwardB: beatJump(beats: performance.loopBeats(for: deck), deck: deck)
        case .cueReturnA, .cueReturnB: pressCue(deck: deck)
        case .freezeA, .freezeB: toggleFreeze(deck: deck)
        case .jogTouchA, .jogTouchB:
            if value > 0 {
                resetControllerWheelJog(deck, restoreRate: false)
                controllerJogTouched.insert(deck)
                guard let frame = playbackSnapshot?[deck].sourceFrame else { return }
                perform(.touch, deck: deck, value: frame, touchRate: 0)
            } else {
                controllerJogTouched.remove(deck)
                perform(.touch, deck: deck, enabled: false)
            }
        case .jogA, .jogB:
            let rate = min(4, max(-4, (value - 0.5) * 8))
            guard controllerJogTouched.contains(deck), let frame = playbackSnapshot?[deck].sourceFrame else { return }
            perform(.touch, deck: deck, value: frame, touchRate: rate)
        case .wheelJogA, .wheelJogB: applyControllerWheelJog(value, deck: deck)
        case .hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A, .hotcue1B,
            .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B:
            if let slot = action.hotcueSlot { cue(slot: slot, deck: deck) }
        case .shift: break
        }
    }
}
