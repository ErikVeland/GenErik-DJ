import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMC6000(body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mc6000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(id: 10, reference: 100, name: "MC6000MK2", identity: .init(id: 10, device: 1, names: ["MC6000MK2"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "MC6000MK2", identity: .init(id: 20, device: 1, names: ["MC6000MK2"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func mc6000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueMC6000PreservesNonSequentialDeckChannels() {
    withMC6000 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        mc6000Packet(
            [0x90, 67, 127, 98, 127, 0x91, 67, 127, 98, 127, 0x92, 67, 127, 99, 127, 0x93, 67, 127, 99, 127], to: input)
        #expect(
            targets == [
                .init(.playA, deck: .a), .init(.loadA, deck: .a), .init(.playA, deck: .c), .init(.loadA, deck: .c),
                .init(.playB, deck: .b), .init(.loadB, deck: .b), .init(.playB, deck: .d), .init(.loadB, deck: .d),
            ])
    }
}

@Test @MainActor func controllerCatalogueMC6000ShiftReleaseSurvivesADeckBankChange() {
    withMC6000 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        mc6000Packet([0x90, 96, 127, 0x91, 67, 127, 0x92, 67, 127], to: input)
        #expect(targets == [.init(.playB, deck: .b)])
        mc6000Packet([0x81, 96, 0, 67, 0, 0x91, 67, 127], to: input)
        #expect(targets.last == .init(.playA, deck: .c))
        mc6000Packet([0x92, 97, 127, 0x90, 67, 127, 0x83, 97, 0, 0x93, 67, 127], to: input)
        #expect(targets.suffix(2) == [.init(.playA, deck: .a), .init(.playB, deck: .d)])
    }
}

@Test @MainActor func controllerCatalogueMC6000BrowserUsesZeroAsForwardAndRejectsOtherCounts() {
    withMC6000 { input in
        var amounts: [Double] = []
        input.onAction = { action, value in if action == .browse { amounts.append(value) } }
        mc6000Packet([0xB0, 84, 0, 84, 0, 84, 64, 84, 1], to: input)
        input.flushPendingActions()
        #expect(amounts == [0.5 + 2.0 / 126])
        mc6000Packet([0xB0, 84, 127], to: input)
        input.flushPendingActions()
        #expect(amounts == [0.5 + 2.0 / 126, 0.5 - 1.0 / 126])
    }
}

@Test @MainActor func controllerCatalogueMC6000PitchBendUsesAllFourteenBits() {
    withMC6000 { input in
        var values: [Double] = []
        input.onTargetAction = { target, value in if target == .init(.tempoB, deck: .b) { values.append(value) } }
        mc6000Packet([0xE2, 0, 0], to: input)
        input.flushPendingActions()
        mc6000Packet([0xE2, 127, 127], to: input)
        input.flushPendingActions()
        #expect(values == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueMC6000JogZeroIsNeutralAndTouchOffCannotStartScratch() {
    withMC6000 { input in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        mc6000Packet([0xB0, 81, 0], to: input)
        input.flushPendingActions()
        #expect(values.isEmpty)
        var decoder = ControllerMIDIDecoder()
        var state = ControllerMIDIValueState()
        for message in decoder.append([0xB0, 81, 0]) {
            #expect(state.decode(message, encoding: .denonJog, number: 81) == .relative(0))
        }
        mc6000Packet([0xB0, 81, 65], to: input)
        input.flushPendingActions()
        #expect(values.last?.1 == 0.625)
        mc6000Packet([0x90, 86, 127, 81, 127, 96, 127, 0x80, 86, 0], to: input)
        #expect(values.filter { $0.0 == .jogTouchA }.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueMC6000EncodesLedTriggersInsteadOfEchoingInputNotes() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Denon DJ MC6000MK2"], automaticOnly: true))
    let feedback = profile.feedback(destination: 20)
    let play = try #require(feedback.first { $0.target == .init(.playB, deck: .b) })
    #expect(play.message(value: 1) == [0xB2, 74, 39])
    #expect(play.message(value: 0) == [0xB2, 75, 39])
    let cue = try #require(feedback.first { $0.target == .init(.cueA, deck: .c) })
    #expect(cue.message(value: 1) == [0xB0, 80, 81])
    #expect(cue.message(value: 0) == [0xB0, 81, 81])
    #expect(play.message(value: .nan) == nil)
    #expect(try JSONDecoder().decode(ControllerFeedbackBinding.self, from: JSONEncoder().encode(play)) == play)
}

@Test @MainActor func controllerCatalogueFeedbackWithoutSeparateOffNumbersKeepsItsExistingPackets() {
    for profile in ControllerFactoryProfile.allCases {
        for output in profile.feedback(destination: 20) where output.offNumber == nil {
            for value in [-1.0, 0, 0.25, 1, 2] {
                let bounded = min(1, max(0, value))
                let amount =
                    output.action.isButton
                    ? (bounded > 0 ? output.onValue : output.offValue) : UInt8((bounded * 127).rounded())
                let status: UInt8 =
                    output.kind == .control
                    ? 0xB0 | output.channel
                    : (bounded > 0 || output.offUsesNoteOn == true ? 0x90 : 0x80) | output.channel
                #expect(output.message(value: value) == [status, output.number, amount])
            }
        }
    }
}

@Test func controllerCatalogueRejectsInvalidShiftInputAndOffTriggerMetadata() throws {
    let base: [String: Any] = [
        "action": "shift", "kind": "note", "channel": 0, "number": 96, "encoding": "absolute", "inverted": false,
        "shiftChannel": 0, "shiftInput": 0,
    ]
    for (key, value) in [("shiftInput", 16 as Any), ("kind", "control" as Any), ("action", "playA" as Any)] {
        var input = base
        input[key] = value
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "invalid", "aliases": ["invalid"], "inputs": [input], "outputs": [], "startup": [],
                    "shutdown": [], "autoSelect": true, "scope": "fixture", "source": "fixture",
                ]
            ],
        ])
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
    }
    for (kind, action, offNumber) in [
        (ControllerFeedbackKind.note, ControllerAction.playA, UInt8(75)), (.control, .levelA, 75),
        (.control, .playA, 128),
    ] {
        let output = ControllerFeedbackBinding(
            destination: 20, action: action, kind: kind, channel: 0, number: 74, offValue: 39, onValue: 39,
            offNumber: offNumber)
        #expect(!output.isValid)
        #expect(output.message(value: 0) == nil)
    }
}
