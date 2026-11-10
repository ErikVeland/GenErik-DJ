import SwiftUI
import TDJCore
import UniformTypeIdentifiers

#if os(iOS)
    import AVFoundation
    import ExternalAccessory
#endif

private enum LearnedControllerProfile: String, CaseIterable {
    case flx4 = "DDJ-FLX4"
    case flx10 = "DDJ-FLX10"
    case rev1 = "DDJ-REV1"
    case rev5 = "DDJ-REV5"
    case ddj1000 = "DDJ-1000"

    static func matching(_ name: String) -> Self? {
        let value = name.uppercased().filter { $0.isLetter || $0.isNumber }
        return allCases.first { value.contains($0.rawValue.filter { $0.isLetter || $0.isNumber }) }
    }
}

struct ControllerSettingsView: View {
    @Bindable var model: ReplicaModel
    @State private var confirmation: ProfileChange?
    @State private var learnSearch = ""
    @State private var confirmClear = false
    @State private var originalZ1Attached = false
    @State private var connectedLights: [String] = []
    #if os(iOS)
        @State private var importingPatternKits = false
        @State private var patternKitMessage: String?
    #endif

    private enum ProfileChange {
        case controls(LearnedControllerProfile)
        case feedback(LearnedControllerProfile)
    }

    private var input: ControllerMIDIConnection { model.controllerInput }
    private var selectedSource: ControllerMIDIConnection.Source? {
        input.sources.first { $0.id == input.selected }
    }
    private var selectedOutput: ControllerMIDIConnection.Source? {
        input.destinations.first { $0.id == input.feedbackSelected }
    }
    private var hasOriginalZ1: Bool {
        originalZ1Attached || connectedLights.contains("Z1") || model.automaticOutputDevice == "Z1"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("During a set").font(.headline)
            if hasOriginalZ1 && !connectedLights.contains("Z1") {
                controllerLights("Z1")
            }
            ForEach(connectedLights, id: \.self) { name in
                controllerLights(name)
            }
            if !hasOriginalZ1 && connectedLights.isEmpty && input.sources.isEmpty {
                Text("Connect a controller to see its settings.").foregroundStyle(.secondary)
            }
            ForEach(input.sources) { source in
                HStack {
                    Text(source.name)
                    Spacer()
                    Text(input.enabled && input.isInputActive(source.id) ? "Active" : "Inactive")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(minHeight: 44)
            }
            SettingsGroup("Configure before a set") {
                SettingsPageLink("Connections & MIDI", detail: "Choose inputs, outputs and controller profiles") {
                    SettingsDetailPage("Connections & MIDI") {
                        if hasOriginalZ1, !input.isZ1BridgeConnected {
                            Toggle(
                                "Z1 direct connection",
                                isOn: Binding(
                                    get: { model.z1Enabled }, set: { if $0 != model.z1Enabled { model.toggleZ1() } }))
                        }
                        midiSettings
                    }
                }
                #if os(iOS)
                    if connectedLights.contains("X1 Mk3") || connectedLights.contains("MX2") {
                        SettingsPageLink("Pattern kits", detail: "Import sounds and patterns for your controller") {
                            SettingsDetailPage("Pattern kits") {
                                Text("Import kits before a set. Select and play patterns from the controller.")
                                Button("Import Pattern Kits…") { importingPatternKits = true }
                            }
                        }
                    }
                #endif
            }
        }
        .confirmationDialog(
            "Replace MIDI mappings?",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
            titleVisibility: .visible
        ) {
            Button("Replace mappings", role: .destructive) { applyProfile() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: refreshOriginalZ1)
        .task {
            while !Task.isCancelled {
                let connected = model.connectedControllerLights()
                if connectedLights != connected { connectedLights = connected }
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            }
        }
        #if os(iOS)
            .fileImporter(isPresented: $importingPatternKits, allowedContentTypes: [.json]) { result in
                Task {
                    do {
                        let count = try await model.importPatternKits(result.get())
                        patternKitMessage = count == 1 ? "1 imported kit ready." : "\(count) imported kits ready."
                    } catch { patternKitMessage = error.localizedDescription }
                }
            }
            .alert(
                "Pattern Kits",
                isPresented: Binding(
                    get: { patternKitMessage != nil }, set: { if !$0 { patternKitMessage = nil } })
            ) {
                Button("OK") { patternKitMessage = nil }
            } message: {
                Text(patternKitMessage ?? "")
            }
            .onReceive(NotificationCenter.default.publisher(for: .EAAccessoryDidConnect).receive(on: RunLoop.main)) {
                _ in refreshOriginalZ1()
            }
            .onReceive(NotificationCenter.default.publisher(for: .EAAccessoryDidDisconnect).receive(on: RunLoop.main)) {
                _ in refreshOriginalZ1()
            }
        #endif
    }

    private func controllerLights(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.subheadline.weight(.semibold))
            Toggle("Beat pulse", isOn: lightBinding(name, \.pulse))
            Toggle("Track-end warning", isOn: lightBinding(name, \.warning))

        }
    }

    private func lightBinding(
        _ controller: String, _ field: WritableKeyPath<ControllerPlaybackLights.Options, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { model.lightOptions(for: controller)[keyPath: field] },
            set: { value in
                var settings = model.lightOptions(for: controller)
                settings[keyPath: field] = value
                model.setLightOptions(settings, for: controller)
            })
    }

    private var midiSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("MIDI input", isOn: Binding(get: { input.enabled }, set: enable))
            if input.enabled && input.sources.isEmpty {
                Text("No MIDI inputs connected.").font(.caption).foregroundStyle(.secondary)
            }
            if input.enabled, !input.sources.isEmpty {
                Picker("Input", selection: Binding(get: { input.selected }, set: input.select)) {
                    Text("Choose an input").tag(Int32?.none)
                    ForEach(input.sources) { source in Text(source.name).tag(Optional(source.id)) }
                }
                if let source = selectedSource {
                    Toggle(
                        "Use this input",
                        isOn: Binding(
                            get: { input.isInputActive(source.id) },
                            set: { input.setInputActive(source.id, active: $0) }))
                    if source.name.localizedCaseInsensitiveContains("Z1") || input.originalZ1Bridge {
                        Toggle(
                            "Original Z1 bridge",
                            isOn: Binding(
                                get: { input.originalZ1Bridge },
                                set: {
                                    if $0 && model.z1Enabled { model.toggleZ1() }
                                    input.setBridgeMode($0)
                                }))
                    }
                    if input.isInputActive(source.id), !input.originalZ1Bridge {
                        if let profile = LearnedControllerProfile.matching(source.name) {
                            Button("Load \(profile.rawValue) controls") { confirmation = .controls(profile) }
                        }
                        SettingsPageLink("Learn controls", detail: "Assign buttons, faders and shifted controls") {
                            SettingsDetailPage("Learn controls") {
                                Text(selectedSource?.name ?? "Selected input").font(.headline)
                                midiLearn
                            }.onDisappear { input.learning = nil }
                        }
                    }
                }
                if !input.destinations.isEmpty {
                    Picker(
                        "Feedback output",
                        selection: Binding(get: { input.feedbackSelected }, set: input.setFeedbackDestination)
                    ) {
                        Text("None").tag(Int32?.none)
                        ForEach(input.destinations) { output in Text(output.name).tag(Optional(output.id)) }
                    }
                    if let output = selectedOutput, !input.originalZ1Bridge {
                        if let profile = LearnedControllerProfile.matching(output.name) {
                            Button("Load \(profile.rawValue) lights") { confirmation = .feedback(profile) }
                        }
                        Toggle(
                            "MIDI feedback",
                            isOn: Binding(
                                get: { input.midiFeedbackEnabled }, set: input.setMIDIFeedbackEnabled
                            )
                        ).disabled(!input.feedbackOutputAvailable || input.selectedFeedbackBindings.isEmpty)
                        SettingsPageLink("Map controller lights", detail: "Set MIDI messages for LEDs and feedback") {
                            SettingsDetailPage("Controller lights") {
                                Text(selectedOutput?.name ?? "Selected output").font(.headline)
                                ControllerFeedbackSettingsView(input: input)
                            }
                        }
                    }
                }
            }
        }
    }

    private var midiLearn: some View {
        VStack(alignment: .leading, spacing: 8) {
            if input.learning != .shift {
                Picker(
                    "Control encoding",
                    selection: Binding(
                        get: { input.learningEncoding }, set: { input.learningEncoding = $0 })
                ) {
                    ForEach(ControllerMIDIEncoding.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
                }
                Toggle(
                    "Reverse direction",
                    isOn: Binding(get: { input.learningInverted }, set: { input.learningInverted = $0 }))
                Toggle(
                    "Shift layer", isOn: Binding(get: { input.learningShifted }, set: { input.learningShifted = $0 }))
            }
            if let action = input.learning {
                Text("Move the control for \(action.title).").font(.caption)
                Button("Cancel learning") { input.learning = nil }
            }
            TextField("Find a control", text: $learnSearch).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Find a MIDI control")
            ForEach(
                ControllerAction.allCases.filter {
                    learnSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(learnSearch)
                }
            ) { action in
                HStack {
                    VStack(alignment: .leading) {
                        Text(action.title)
                        Text(input.bindingName(action)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Learn") {
                        if action == .shift {
                            input.learningShifted = false
                            input.learningEncoding = .absolute
                            input.learningInverted = false
                        }
                        input.learning = action
                    }
                }
            }
            Button("Clear learned controls…", role: .destructive) { confirmClear = true }
                .disabled(input.bindingCount == 0)
                .confirmationDialog(
                    "Clear learned controls for this input?", isPresented: $confirmClear, titleVisibility: .visible
                ) {
                    Button("Clear controls", role: .destructive) {
                        input.learning = nil
                        input.clearBindings()
                    }
                    Button("Cancel", role: .cancel) {}
                }
        }
    }

    private func applyProfile() {
        guard let confirmation else { return }
        switch confirmation {
        case .controls(.flx4): input.applyDDJFLX4Profile()
        case .controls(.flx10): input.applyDDJFLX10Profile()
        case .controls(.rev1): input.applyDDJREV1Profile()
        case .controls(.rev5): input.applyDDJREV5Profile()
        case .controls(.ddj1000): input.applyDDJ1000Profile()
        case .feedback(.flx4): input.applyDDJFLX4FeedbackProfile()
        case .feedback(.flx10): input.applyDDJFLX10FeedbackProfile()
        case .feedback(.rev1): input.applyDDJREV1FeedbackProfile()
        case .feedback(.rev5): input.applyDDJREV5FeedbackProfile()
        case .feedback(.ddj1000): input.applyDDJ1000FeedbackProfile()
        }
        self.confirmation = nil
    }

    private func refreshOriginalZ1() {
        #if os(iOS)
            originalZ1Attached = EAAccessoryManager.shared().connectedAccessories.contains { accessory in
                accessory.protocolStrings.contains("com.native-instruments.traktordj.kontrolz1")
            }
        #endif
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

    func controllerValue(_ action: ControllerAction, targetDeck: DeckID? = nil) -> Double? {
        let deck = targetDeck ?? action.deck
        if let slot = action.hotcueSlot {
            guard let trackID = loaded[deck] else { return 0 }
            return performance.cues[trackID]?[slot] == nil ? 0 : 1
        }
        guard let snapshot = playbackSnapshot else { return nil }
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
    func applyController(
        _ action: ControllerAction, value: Double, refreshMixer: Bool = true, targetDeck: DeckID? = nil
    ) {
        guard value.isFinite, (0...1).contains(value) else { return }
        let deck = targetDeck ?? action.deck
        func mix(_ parameter: MixerParameter, value: Double, deck: DeckID = .a) {
            if submitMixer(parameter, value: value, deck: deck), refreshMixer { refreshPlayback() }
        }
        switch action {
        case .playA, .playB: pressPlay(deck: deck)
        case .syncA, .syncB: toggleSync(deck: deck)
        case .keylockA, .keylockB: toggleKeylock(deck: deck)
        case .cueA, .cueB: mix(.cue, value: playbackSnapshot?[deck].mixer.cue == true ? 0 : 1, deck: deck)
        case .levelA, .levelB: mix(.volume, value: value, deck: deck)
        case .gainA, .gainB: mix(.gain, value: pow(4, 2 * value - 1), deck: deck)
        case .lowA, .lowB: mix(.low, value: 2 * value, deck: deck)
        case .midA, .midB: mix(.mid, value: 2 * value, deck: deck)
        case .highA, .highB: mix(.high, value: 2 * value, deck: deck)
        case .filterA, .filterB: mix(.filterX, value: 2 * value - 1, deck: deck)
        case .filterToggleA, .filterToggleB:
            mix(.filterEnabled, value: playbackSnapshot?[deck].mixer.filterEnabled == true ? 0 : 1, deck: deck)
        case .fxA, .fxB: setHardwareEffectX(value, deck: deck)
        case .fxToggleA, .fxToggleB: toggleHardwareEffect(deck: deck)
        case .crossfader: mix(.crossfader, value: value)
        case .cueMix: mix(.cueBlend, value: value)
        case .master: mix(.master, value: value)
        case .monitor: mix(.monitor, value: value)
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
