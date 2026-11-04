import Foundation

@main struct ControllerValueCheck {
    static func main() {
        var parser = ControllerMIDIDecoder()
        var state = ControllerMIDIValueState()
        let pair = parser.append([0xb0, 39, 127, 7, 127, 39, 127])
        precondition(
            state.decode(pair[0], encoding: .paired14Bit, number: 7) == nil, "LSB alone must not become a fader value.")
        _ = state.decode(pair[1], encoding: .paired14Bit, number: 7)
        precondition(state.decode(pair[2], encoding: .paired14Bit, number: 7) == .absolute(1))
        let reset = parser.append([7, 0])[0]
        precondition(
            state.decode(reset, encoding: .paired14Bit, number: 7) == .absolute(0),
            "A new MSB resets the prior low bits.")
        for (encoding, bytes, expected) in [
            (ControllerMIDIEncoding.twosComplement, [UInt8(1), 127, 0], [1, -1, 0]),
            (.binaryOffset, [65, 63, 64], [1, -1, 0]), (.signedBit, [1, 65, 64], [1, -1, 0]),
        ] {
            for (byte, value) in zip(bytes, expected) {
                let message = parser.append([0xb0, 10, byte])[0]
                precondition(state.decode(message, encoding: encoding, number: 10) == .relative(value))
            }
        }
        let note = parser.append([0x90, 10, 127])[0]
        precondition(state.decode(note, encoding: .twosComplement, number: 10) == nil)
        var other = ControllerMIDIValueState()
        precondition(
            other.decode(pair[2], encoding: .paired14Bit, number: 7) == nil,
            "High-resolution state must remain input/binding-local.")
        print("Controller value encoding checks passed.")
    }
}
