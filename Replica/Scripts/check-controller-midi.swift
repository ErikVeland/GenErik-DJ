import Foundation

@main struct ControllerMIDICheck {
    static func main() {
        var decoder = ControllerMIDIDecoder()
        precondition(decoder.append([0x90, 60]).isEmpty)
        let notes = decoder.append([100, 61, 0, 0x80, 60, 64])
        precondition(
            notes.map(\.value) == [100, 0, 0], "Note-off and zero-velocity note-on must release the same control.")
        precondition(notes.map(\.number) == [60, 61, 60])
        let controls = decoder.append([0xb2, 7, 0xf8, 127, 8, 64])
        precondition(controls.map(\.value) == [127, 64], "Clock bytes must not break running status.")
        precondition(controls.allSatisfy { $0.channel == 2 && $0.kind == .control })
        precondition(
            decoder.append([0xf0, 1, 2, 3, 0xf7, 7, 127]).isEmpty, "System data must not become controller actions.")
        let pitches = decoder.append([0xe0, 0, 0, 127, 127])
        precondition(pitches.map(\.value) == [0, 16383])
        precondition(pitches.map(\.normalized) == [0, 1])
        var other = ControllerMIDIDecoder()
        precondition(other.append([7, 127]).isEmpty, "Running status must not leak between inputs.")
        let expression = decoder.append([0xa3, 60, 66, 0xd4, 55, 0xc5, 12])
        precondition(expression.map(\.kind) == [.polyPressure, .pressure, .program])
        precondition(expression.map(\.channel) == [3, 4, 5])
        precondition(expression.map(\.number) == [60, 0, 12])
        precondition(expression.map(\.value) == [66, 55, 127])
        print("Controller MIDI packet checks passed.")
    }
}
