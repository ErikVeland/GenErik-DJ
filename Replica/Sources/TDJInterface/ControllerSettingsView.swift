import AVFoundation
import SwiftUI
import TDJCore
#if os(iOS)
import ExternalAccessory
#endif

struct ControllerSettingsView: View {
    @Bindable var model: ReplicaModel
    @State private var connections: [String] = []
    private var input: ControllerMIDIConnection { model.controllerInput }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Controllers").font(.headline)
            Toggle("Enable controller input", isOn: Binding(get: { input.enabled }, set: enable))
            Text(input.status).foregroundStyle(.secondary)
            if input.enabled {
                Picker("Input", selection: Binding(get: { input.selected }, set: input.select)) {
                    Text("Choose an input").tag(Int32?.none)
                    ForEach(input.sources) { source in Text(source.name).tag(Optional(source.id)) }
                }
                Button("Refresh connections") { input.refreshSources(); refreshConnections() }
                Text(input.lastInput).font(.caption).foregroundStyle(.secondary)
                if let action = input.learning {
                    Text("Move the control for \(action.title). Learning does not operate the deck.")
                    Button("Cancel learning") { input.learning = nil }
                }
                Text("Learn a button for switches, or an absolute knob/fader for amounts. Relative encoders and controller lights/screens are not implemented in this version.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(ControllerAction.allCases) { action in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(action.title)
                            Text(input.bindingName(action)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(input.learning == action ? "Waiting…" : "Learn") { input.learning = action }
                            .disabled(input.selected == nil)
                    }
                }
                Button("Clear learned controls", role: .destructive) { input.clearBindings() }
                    .disabled(input.bindingCount == 0)
            }
            Divider()
            Text("Z1 connection").font(.headline)
            Text("For the original Z1, MIDI mode uses MODE + both headphone cue buttons. A MIDI mode setting does not guarantee that iPadOS exposes an input.")
                .font(.caption).foregroundStyle(.secondary)
            Text("If the controller has only an accessory or audio connection, its controls need an implemented accessory protocol or the approved hardware bridge.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(connections.enumerated()), id: \.offset) { _, text in
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
            Button("Refresh connection details") { refreshConnections() }
            ShareLink("Share controller connection details", item: ([input.status, input.lastInput] + connections).joined(separator: "\n"))
        }.onAppear { refreshConnections() }
    }
    private func enable(_ enabled: Bool) {
        if enabled {
            let model = model
            input.onAction = { [weak model] action, value in model?.applyController(action, value: value) }
            input.start()
        } else { input.stop() }
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
        case .fxA, .fxB: setHardwareEffectX(value, deck: deck)
        case .fxToggleA, .fxToggleB: toggleHardwareEffect(deck: deck)
        case .crossfader: setMixer(.crossfader, value: value)
        case .cueMix: setMixer(.cueBlend, value: value)
        }
    }
}
