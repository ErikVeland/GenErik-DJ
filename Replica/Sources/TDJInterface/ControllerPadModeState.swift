import TDJCore

struct ControllerPadModeState {
    private let modes: [ControllerProfileData.InputMode]
    private var selected: [UInt8: UInt8]

    init(modes: [ControllerProfileData.InputMode]) {
        self.modes = modes
        selected = Dictionary(
            uniqueKeysWithValues: modes.compactMap { mode in
                mode.initial.map { (mode.channel, $0) }
            })
    }

    mutating func receive(_ message: ControllerMIDIMessage) -> ControllerProfileData.InputMode? {
        guard message.group == 0, message.kind == .note, !message.isNoteOff, message.value > 0 else { return nil }
        if let mode = modes.first(where: {
            $0.invalidatingSelectors?.contains(.init(channel: message.channel, number: message.number)) == true
        }) {
            selected[mode.channel] = nil
            return mode
        }
        guard let mode = modes.first(where: { $0.channel == message.channel && $0.numbers.contains(message.number) })
        else { return nil }
        selected[mode.channel] = message.number
        return mode
    }

    func allows(_ binding: ControllerBinding) -> Bool {
        binding.requiredMode == nil || selected[binding.channel] == binding.requiredMode
    }

    func isSelected(_ number: UInt8, channel: UInt8) -> Bool {
        selected[channel] == number
    }
}
