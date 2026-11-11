import SwiftUI
import TDJCore
import UniformTypeIdentifiers

#if os(iOS)
    import AVFoundation
    import ExternalAccessory
#endif

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
        case controls(ControllerFactoryProfile)
        case feedback(ControllerFactoryProfile)
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
                    if let profile = input.factoryProfileName(source: source.id) {
                        Text("\(profile) · Automatic").font(.caption).foregroundStyle(.secondary)
                    }
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
                        if let profile = ControllerFactoryProfile.matching([source.name]) {
                            Button("Load \(profile.rawValue) controls") { confirmation = .controls(profile) }
                            if let scope = profile.definition?.scope {
                                Text(scope).font(.caption).foregroundStyle(.secondary)
                            }
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
                        if let profile = ControllerFactoryProfile.matching([output.name]) {
                            Button("Load \(profile.rawValue) lights") { confirmation = .feedback(profile) }
                        }
                        Toggle(
                            "MIDI feedback",
                            isOn: Binding(
                                get: { input.isSelectedFeedbackEnabled }, set: input.setMIDIFeedbackEnabled
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
        case .controls(let profile): input.applyFactoryProfile(profile)
        case .feedback(let profile): input.applyFactoryFeedbackProfile(profile)
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
        model.configureControllerMIDI()
        input.setEnabled(enabled)
    }
}
