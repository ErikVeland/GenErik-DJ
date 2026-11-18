import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withKontrolOne(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) -> Void
) {
    let suite = "kontrol-one-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "Kontrol One", identity: .init(id: 10, device: 1, names: ["Kontrol One"])),
        .init(id: 11, reference: 101, name: "Kontrol One", identity: .init(id: 11, device: 2, names: ["Kontrol One"])),
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    body(input)
}

@MainActor private func kontrolPacket(_ bytes: [UInt8], source: Int32 = 10, to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueKontrolOneUsesIndependentAliasesAndAllNativeBaseButtons() {
    #expect(ControllerFactoryProfile.matching(["DJ-Tech Kontrol One"])?.definition?.inputProtocol == .kontrolOne)
    for name in ["DJ-Tech CDJ-101", "DJ-Tech DJM-101", "DJ TechTools MIDI Fighter"] {
        #expect(ControllerFactoryProfile.matching([name])?.definition?.inputProtocol != .kontrolOne)
    }
    for decks in [DeckID.primary, DeckID.allCases] {
        withKontrolOne(decks: decks) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { if !$0.action.isJog { events.append(($0, $1)) } }
            let buttons: [(UInt8, ControllerAction, Double?)] = [
                (27, .playA, nil), (28, .cuePreviewA, nil), (29, .syncA, nil),
                (14, .hotcue5A, nil), (13, .hotcue6A, nil), (12, .hotcue7A, nil), (11, .hotcue8A, nil),
                (19, .toggleFixedLoopA, 1), (18, .toggleFixedLoopA, 2), (17, .toggleFixedLoopA, 4),
                (16, .reloopA, nil), (24, .loopInA, nil), (23, .loopOutA, nil),
                (22, .loopDownA, nil), (21, .loopUpA, nil),
            ]
            for (channel, deck) in DeckID.allCases.enumerated() {
                for (number, action, argument) in buttons {
                    events.removeAll()
                    kontrolPacket([0x90 + UInt8(channel), number, 127, 0x80 + UInt8(channel), number, 100], to: input)
                    let count = decks.contains(deck) ? (action.isMomentary ? 2 : 1) : 0
                    #expect(
                        events.map(\.0)
                            == Array(
                                repeating: .init(action.assigned(to: deck), deck: deck, argument: argument),
                                count: count))
                    if action.isMomentary && count > 0 { #expect(events.map(\.1) == [1, 0]) }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueKontrolOnePreservesHeldModifiersAcrossDeckChangesAndSourceIsolation() {
    for modifier: UInt8 in [1, 2, 3, 4, 25, 26, 30] {
        withKontrolOne { input in
            var events: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { events.append(action) } }
            kontrolPacket([0x90, modifier, 127, 27, 127, 27, 0], to: input)
            kontrolPacket([0x92, 27, 127, 27, 0], to: input)
            #expect(events.isEmpty)
            kontrolPacket([0x90, 27, 127, 27, 0], source: 11, to: input)
            #expect(events == [.playA])
            events.removeAll()
            kontrolPacket([0x82, modifier, 127, 0x92, 27, 127, 27, 0], to: input)
            #expect(events == [.playA])
        }
    }
}

@Test @MainActor func controllerCatalogueKontrolOneChangesDeckWithoutLeavingCueHeldOrReleasingAnotherSource() {
    withKontrolOne { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in if action == .cuePreviewA { events.append((action, value)) } }
        kontrolPacket([0x90, 28, 127], to: input)
        kontrolPacket([0x90, 28, 127], source: 11, to: input)
        kontrolPacket([0x91, 27, 127], to: input)
        #expect(events.map(\.1) == [1])
        kontrolPacket([0x80, 28, 100], source: 11, to: input)
        #expect(events.map(\.1) == [1, 0])
        kontrolPacket([0x90, 28, 127], to: input)
        kontrolPacket([0xB2, 33, 64], to: input)
        #expect(events.map(\.1) == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueKontrolOneUsesNativeKnobStepsPitchCentreAndReviewedScratchUnits() {
    withKontrolOne { input in
        var events: [(ControllerActionTarget, Double)] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.currentTargetValue = { _ in 0.5 }
        input.onTargetAction = { if !$0.action.isJog { events.append(($0, $1)) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        for (channel, deck) in DeckID.allCases.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [(55, .gainA), (54, .highA), (53, .midA), (52, .lowA)] {
                events.removeAll()
                kontrolPacket([0xB0 + UInt8(channel), number, 127], to: input)
                #expect(events.last?.0 == .init(action.assigned(to: deck), deck: deck))
                #expect(abs((events.last?.1 ?? 0) - 0.52) < 0.00001)
                kontrolPacket([0xB0 + UInt8(channel), number, 1], to: input)
                #expect(abs((events.last?.1 ?? 0) - 0.48) < 0.00001)
            }
            events.removeAll()
            for raw: UInt8 in [64, 0, 127] { kontrolPacket([0xB0 + UInt8(channel), 33, raw], to: input) }
            #expect(events.map(\.1) == [0.5, 1, 0])
            jogs.removeAll()
            kontrolPacket([0xB0 + UInt8(channel), 32, 127], to: input)
            kontrolPacket([0xB0 + UInt8(channel), 32, 1], to: input)
            #expect(jogs.map(\.1) == [.relative(1), .relative(-1)])
            #expect(
                jogs.allSatisfy { $0.0 == .init(ControllerAction.jogA.assigned(to: deck), deck: deck, argument: 202.5) }
            )
        }
    }
}

@Test @MainActor func controllerCatalogueKontrolOneReconnectAndOverloadResetContactsAndDecoder() {
    withKontrolOne { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { events.append(action) } }
        kontrolPacket([0x90, 26, 127], to: input)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        kontrolPacket([0x90, 27, 127, 27, 0], to: input)
        #expect(events == [.playA])
        events.removeAll()
        #expect(input.receiveBytes([0x91, 27, 127], source: 10, limit: 1) == nil)
        #expect(events.isEmpty)
        #expect(input.status.contains("overload"))
    }
}

@Test func controllerCatalogueKontrolOneLimitsDirectionStepsToItsReviewedKnobAddresses() throws {
    func valid(protocolName: String, number: Int, action: String = "gainA", step: Double = 0.02) throws -> Bool {
        let data = Data(
            """
            {"id":"step-test","aliases":["step-test"],"inputs":[
            {"action":"\(action)","kind":"control","channel":0,"number":\(number),"encoding":"twosComplement","inverted":false,"directionStep":\(step)}
            ],"outputs":[],"startup":[],"shutdown":[],"autoSelect":false,"scope":"test","source":"test","inputProtocol":"\(protocolName)"}
            """.utf8)
        return try JSONDecoder().decode(ControllerProfileData.self, from: data).isValid
    }
    #expect(try valid(protocolName: "kontrolOne", number: 55))
    #expect(try !valid(protocolName: "cdj101", number: 55))
    #expect(try !valid(protocolName: "kontrolOne", number: 51))
    #expect(try !valid(protocolName: "kontrolOne", number: 55, action: "master"))
    #expect(try !valid(protocolName: "kontrolOne", number: 55, step: 0.2))
}
