import Foundation
import TDJCore

extension ControllerMIDIConnection {
    /**
     * Uses the FLX2 E1 MIDI table. The global CFX knobs differ from the deck EQ channels.
     */
    static func ddjFLX2Bindings(source: Int32) -> [ControllerBinding] {
        let omitted: Set<ControllerAction> = [.gainA, .gainB, .cueMix, .shift]
        var profile = ddjFLX4BasicBindings(source: source).filter { !omitted.contains($0.action) }
        func binding(
            _ action: ControllerAction, _ kind: ControllerMIDIMessage.Kind, _ channel: UInt8, _ number: UInt8,
            _ encoding: ControllerMIDIEncoding = .absolute, shifted: Bool = false
        ) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number,
                parameter: nil, noteNumber: nil, action: action, encoding: encoding,
                inverted: false, shifted: shifted)
        }
        profile += [
            binding(.tempoA, .control, 0, 0, .paired14Bit),
            binding(.tempoB, .control, 1, 0, .paired14Bit),
            binding(.tempoA, .control, 0, 0, .paired14Bit, shifted: true),
            binding(.tempoB, .control, 1, 0, .paired14Bit, shifted: true),
            binding(.filterKnobA, .control, 6, 23, .paired14Bit),
            binding(.filterKnobB, .control, 6, 24, .paired14Bit),
            binding(.shift, .note, 0, 63), binding(.shift, .note, 1, 63),
            binding(.jogTouchA, .note, 0, 103, shifted: true),
            binding(.jogTouchB, .note, 1, 103, shifted: true),
            binding(.jogA, .control, 0, 41, .binaryOffset, shifted: true),
            binding(.jogB, .control, 1, 41, .binaryOffset, shifted: true),
            binding(.wheelJogA, .control, 0, 33, .binaryOffset, shifted: true),
            binding(.wheelJogB, .control, 1, 33, .binaryOffset, shifted: true),
        ]
        return profile
    }

    static func ddjFLX2FeedbackBindings(destination: Int32) -> [ControllerFeedbackBinding] {
        ddjFLX4FeedbackBindings(destination: destination)
    }

    static func ddjFLX4Bindings(source: Int32) -> [ControllerBinding] {
        var profile = ddjFLX4BasicBindings(source: source).filter { $0.action != .shift }
        func binding(
            _ action: ControllerAction, _ kind: ControllerMIDIMessage.Kind, _ channel: UInt8, _ number: UInt8,
            _ encoding: ControllerMIDIEncoding = .absolute, shifted: Bool = false
        ) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number,
                parameter: nil, noteNumber: nil, action: action, encoding: encoding,
                inverted: false, shifted: shifted)
        }
        for channel in UInt8(0)...1 {
            let a = channel == 0
            profile += [
                binding(a ? .tempoA : .tempoB, .control, channel, 0, .paired14Bit),
                binding(a ? .tempoA : .tempoB, .control, channel, 0, .paired14Bit, shifted: true),
                binding(a ? .loopA : .loopB, .note, channel, 77),
                binding(a ? .loopDownA : .loopDownB, .note, channel, 81),
                binding(a ? .loopUpA : .loopUpB, .note, channel, 83),
                binding(a ? .jumpBackA : .jumpBackB, .note, channel, 62, shifted: true),
                binding(a ? .jumpForwardA : .jumpForwardB, .note, channel, 61, shifted: true),
                binding(.shift, .note, channel, 63),
                binding(a ? .jogTouchA : .jogTouchB, .note, channel, 103, shifted: true),
                binding(a ? .jogA : .jogB, .control, channel, 41, .binaryOffset, shifted: true),
            ]
        }
        profile += [
            binding(.filterKnobA, .control, 6, 23, .paired14Bit),
            binding(.filterKnobB, .control, 6, 24, .paired14Bit),
            binding(.browse, .control, 6, 64, .binaryOffset),
            binding(.openGroup, .note, 6, 65),
            binding(.loadA, .note, 6, 70), binding(.loadB, .note, 6, 71),
        ]
        return profile
    }

    /**
     * The DDJ-400 shares these documented addresses. Its master knob controls hardware audio.
     */
    static func ddj400Bindings(source: Int32) -> [ControllerBinding] {
        ddjFLX4Bindings(source: source).filter { $0.action != .master }
    }

    private static func ddjFLX4BasicBindings(source: Int32) -> [ControllerBinding] {
        func binding(
            _ action: ControllerAction, kind: ControllerMIDIMessage.Kind, channel: UInt8, number: UInt8,
            encoding: ControllerMIDIEncoding = .absolute
        ) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number, parameter: nil,
                noteNumber: nil, action: action, encoding: encoding, inverted: false, shifted: false)
        }
        var profile: [ControllerBinding] = []
        for (channel, deck) in [(UInt8(0), "A"), (UInt8(1), "B")] {
            let play: ControllerAction = deck == "A" ? .playA : .playB
            let cue: ControllerAction = deck == "A" ? .cueReturnA : .cueReturnB
            let headphoneCue: ControllerAction = deck == "A" ? .cueA : .cueB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            profile += [
                binding(play, kind: .note, channel: channel, number: 11),
                binding(cue, kind: .note, channel: channel, number: 12),
                binding(headphoneCue, kind: .note, channel: channel, number: 84),
                binding(sync, kind: .note, channel: channel, number: 88),
            ]
            let controls: [(ControllerAction, UInt8)] =
                deck == "A"
                ? [(.gainA, 4), (.highA, 7), (.midA, 11), (.lowA, 15), (.levelA, 19)]
                : [(.gainB, 4), (.highB, 7), (.midB, 11), (.lowB, 15), (.levelB, 19)]
            profile += controls.map {
                binding($0.0, kind: .control, channel: channel, number: $0.1, encoding: .paired14Bit)
            }
            let padChannel: UInt8 = deck == "A" ? 7 : 9
            let hotcues: [ControllerAction] =
                deck == "A"
                ? [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A]
                : [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B]
            profile += hotcues.enumerated().map {
                binding($0.element, kind: .note, channel: padChannel, number: UInt8($0.offset))
            }
            let jog: ControllerAction = deck == "A" ? .jogA : .jogB
            let jogTouch: ControllerAction = deck == "A" ? .jogTouchA : .jogTouchB
            let wheelJog: ControllerAction = deck == "A" ? .wheelJogA : .wheelJogB
            profile += [
                binding(jog, kind: .control, channel: channel, number: 34, encoding: .binaryOffset),
                binding(jog, kind: .control, channel: channel, number: 35, encoding: .binaryOffset),
                binding(jogTouch, kind: .note, channel: channel, number: 54),
                binding(wheelJog, kind: .control, channel: channel, number: 33, encoding: .binaryOffset),
            ]
        }
        profile += [
            binding(.crossfader, kind: .control, channel: 6, number: 31, encoding: .paired14Bit),
            binding(.master, kind: .control, channel: 6, number: 8, encoding: .paired14Bit),
            binding(.cueMix, kind: .control, channel: 6, number: 12, encoding: .paired14Bit),
            binding(.monitor, kind: .control, channel: 6, number: 13, encoding: .paired14Bit),
            binding(.shift, kind: .note, channel: 6, number: 63),
        ]
        return profile
    }

    static func ddjFLX4FeedbackBindings(destination: Int32) -> [ControllerFeedbackBinding] {
        let profile: [ControllerFeedbackBinding] = [
            .init(
                destination: destination, action: .playA, kind: .note, channel: 0, number: 11, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .syncA, kind: .note, channel: 0, number: 88, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .cueA, kind: .note, channel: 0, number: 84, offValue: 0, onValue: 127,
                offUsesNoteOn: true),
            .init(
                destination: destination, action: .playB, kind: .note, channel: 1, number: 11, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .syncB, kind: .note, channel: 1, number: 88, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .cueB, kind: .note, channel: 1, number: 84, offValue: 0, onValue: 127,
                offUsesNoteOn: true),
        ]
        var completeProfile = profile
        for (padChannel, padActions) in [
            (
                UInt8(7),
                [
                    ControllerAction.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A,
                    .hotcue8A,
                ]
            ),
            (
                UInt8(9),
                [
                    ControllerAction.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B,
                    .hotcue8B,
                ]
            ),
        ] {
            for (number, action) in padActions.enumerated() {
                completeProfile.append(
                    .init(
                        destination: destination, action: action, kind: .note, channel: padChannel,
                        number: UInt8(number), offValue: 0, onValue: 127, offUsesNoteOn: true))
            }
        }
        return completeProfile
    }
}
