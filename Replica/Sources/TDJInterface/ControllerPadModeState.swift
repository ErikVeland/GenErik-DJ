import TDJCore

struct ControllerPadModeState {
    private let modes: [ControllerProfileData.InputMode]
    private var selected: [UInt8: UInt8]

    init(modes: [ControllerProfileData.InputMode]) {
        self.modes = modes
        selected = Dictionary(uniqueKeysWithValues: modes.map { ($0.channel, $0.initial) })
    }

    mutating func receive(_ message: ControllerMIDIMessage) -> ControllerProfileData.InputMode? {
        guard message.group == 0, message.kind == .note, !message.isNoteOff, message.value > 0,
            let mode = modes.first(where: { $0.channel == message.channel && $0.numbers.contains(message.number) })
        else { return nil }
        selected[mode.channel] = message.number
        return mode
    }

    func allows(_ binding: ControllerBinding) -> Bool {
        binding.requiredMode == nil || selected[binding.channel] == binding.requiredMode
    }
}
