import SwiftUI

/// Configures generic MIDI note and Control Change feedback.
struct ControllerFeedbackSettingsView: View {
    @Bindable var input: ControllerMIDIConnection
    @State private var action: ControllerAction = .playA
    @State private var kind: ControllerFeedbackKind = .note
    @State private var channel = 1
    @State private var number = 0
    @State private var offValue = 0
    @State private var onValue = 127

    private var actions: [ControllerAction] { ControllerAction.allCases.filter(\.supportsFeedback) }
    private var selectedActionIsButton: Bool { action.isButton }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Generic MIDI feedback").font(.headline)
            Text("Choose the output messages for this device. The app does not assume a controller model or LED layout.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Action", selection: $action) {
                ForEach(actions) { item in Text(item.title).tag(item) }
            }
            .onChange(of: action) { _, _ in loadBinding() }
            if selectedActionIsButton {
                Picker("Message", selection: $kind) {
                    ForEach(ControllerFeedbackKind.allCases, id: \.self) { item in Text(item.title).tag(item) }
                }
                Stepper("Off value: \(offValue)", value: $offValue, in: 0...127)
                Stepper("On value: \(onValue)", value: $onValue, in: 0...127)
            } else {
                Text("Continuous actions send 0–127 as Control Change values.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Stepper("Output channel: \(channel)", value: $channel, in: 1...16)
            Stepper("Message number: \(number)", value: $number, in: 0...127)
            Button("Save feedback mapping") { saveBinding() }

            if !input.selectedFeedbackBindings.isEmpty {
                Divider()
                ForEach(input.selectedFeedbackBindings) { binding in
                    HStack {
                        Text("\(binding.action.title) · \(input.feedbackBindingName(binding.action))")
                            .font(.caption).lineLimit(1)
                        Spacer()
                        Button("Remove", role: .destructive) { input.removeFeedbackBinding(binding.action) }
                            .font(.caption)
                    }
                }
            }
        }
        .onAppear(perform: loadBinding)
        .onChange(of: input.feedbackSelected) { _, _ in loadBinding() }
    }

    private func loadBinding() {
        guard let binding = input.selectedFeedbackBindings.first(where: { $0.action == action }) else {
            kind = selectedActionIsButton ? .note : .control
            channel = 1; number = 0; offValue = 0; onValue = 127
            return
        }
        kind = binding.kind
        channel = Int(binding.channel) + 1
        number = Int(binding.number)
        offValue = Int(binding.offValue)
        onValue = Int(binding.onValue)
    }

    private func saveBinding() {
        input.setFeedbackBinding(action: action,
                                 kind: selectedActionIsButton ? kind : .control,
                                 channel: UInt8(channel - 1), number: UInt8(number),
                                 offValue: UInt8(offValue), onValue: UInt8(onValue))
    }
}
