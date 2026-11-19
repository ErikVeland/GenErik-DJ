import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalMC6000(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "original-mc6000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { DeckID.allCases })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DN-MC6000",
            identity: .init(id: id, device: UInt32(id), names: ["DN-MC6000"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["DN-MC6000"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.bindingCount == 224)
    try body(input)
}

@MainActor private func originalMC6000Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalMC6000KeepsACBDAndBothVelocity64ReleaseForms() throws {
    try withOriginalMC6000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in [DeckID.a, .c, .b, .d].enumerated() {
            for number: UInt8 in [66, 12, 13, 81] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    originalMC6000Packet(
                        [
                            0x90 + UInt8(channel), number, 64, number, 64, off + UInt8(channel), number,
                            off == 0x80 ? 64 : 0,
                        ], input)
                    #expect(
                        events.map(\.1) == [number == 81 ? 1 : 64.0 / 127, 0] && events.allSatisfy { $0.0.deck == deck }
                    )
                }
            }
            for (number, action): (UInt8, ControllerAction) in [
                (67, .playA), (107, .syncA), (6, .keylockA), (23, .hotcue1A), (32, .hotcue4A), (29, .loopA),
                (55, .loopInA), (57, .loopOutA), (105, .loopDownA), (106, .loopUpA),
            ] {
                events.removeAll()
                originalMC6000Packet([0x90 + UInt8(channel), number, 64, number, 64, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
        }
        events.removeAll()
        originalMC6000Packet([0x90, 98, 64, 98, 0, 99, 64, 99, 0], input)
        #expect(events.map(\.0.deck) == [.a, .b])
    }
}

@Test @MainActor func controllerCatalogueOriginalMC6000ShiftBanksAndSourcesReleaseOnlyOwnedContacts() throws {
    try withOriginalMC6000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        originalMC6000Packet([0x90, 66, 64, 0x91, 66, 64, 0x92, 66, 64], input)
        originalMC6000Packet([0x90, 66, 64], input, source: 11)
        originalMC6000Packet([0x90, 3, 64], input)
        #expect(events.map(\.0.deck) == [.a, .c, .b, .c])
        originalMC6000Packet([0x80, 66, 64], input, source: 11)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        originalMC6000Packet([0x90, 66, 64, 0x80, 3, 64], input)
        #expect(events.last?.0.deck == .a && events.last?.1 == 64.0 / 127)
        originalMC6000Packet([0x90, 96, 64], input)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        events.removeAll()
        originalMC6000Packet([0x91, 23, 64, 23, 0, 0x92, 23, 64, 23, 0, 0xB0, 84, 0], input)
        #expect(events.count == 1 && events.first?.0.deck == .b)
        originalMC6000Packet([0x81, 96, 64, 0x91, 23, 64, 23, 0], input)
        #expect(events.last?.0.deck == .c)
    }
}

@Test @MainActor func controllerCatalogueOriginalMC6000JogMixerAndBrowserKeepTheirOwnContracts() throws {
    try withOriginalMC6000 { input in
        var jogs: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { target, value in if case .relative(let count) = value { jogs.append((target, count)) } }
        for (channel, deck) in [DeckID.a, .c, .b, .d].enumerated() {
            jogs.removeAll()
            for value: UInt8 in [65, 63, 127, 1, 64, 0] {
                originalMC6000Packet([0xB0 + UInt8(channel), 81, value], input)
            }
            #expect(jogs.map(\.1) == [1, -1, 63, -63])
            #expect(jogs.allSatisfy { $0.0.deck == deck && $0.0.argument == 2000 })
        }
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (index, deck) in DeckID.allCases.enumerated() {
            events.removeAll()
            let number: UInt8 = [5, 11, 16, 21][index]
            originalMC6000Packet([0xB0, number, 64], input)
            originalMC6000Packet([0xB0, number, 127], input)
            #expect(events.map(\.0.deck) == [deck, deck] && events.last?.1 == 1)
        }
        events.removeAll()
        for value: UInt8 in [0, 127, 1, 126, 64] { originalMC6000Packet([0xB0, 84, value], input) }
        #expect(events.map(\.0.action) == [.browse, .browse])
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        events.removeAll()
        originalMC6000Packet([0xE2, 0, 64], input)
        originalMC6000Packet([0xE2, 127, 127], input)
        #expect(events.count == 2 && events.allSatisfy { $0.0.deck == .b && $0.0.action == .tempoB })
        #expect(events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueOriginalMC6000LampsStayManualWithoutFaderQueryOrSiblingAliases() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DN-MC6000"]))
    let definition = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && definition.inputs.count == 112 && definition.outputs.count == 40)
    #expect(definition.startup.isEmpty && definition.shutdown.isEmpty && definition.audioOutput == nil)
    let light = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue4B && $0.targetDeck == .d })
    #expect(light.message(value: 1) == [0xB3, 74, 23] && light.message(value: 0) == [0xB3, 75, 23])
    let pfl = try #require(profile.feedback(destination: 20).first { $0.action == .cueB && $0.targetDeck == .d })
    #expect(pfl.message(value: 1) == [0xB0, 80, 87] && pfl.message(value: 0) == [0xB0, 81, 87])
    for name in ["MC6000MK2", "MC6000 MK2", "MC6000 clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}
