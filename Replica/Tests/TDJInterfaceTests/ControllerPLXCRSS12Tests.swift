import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withCRSS(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "plx-crss12-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "PLX-CRSS12",
            identity: .init(id: id, device: UInt32(id), names: ["PLX-CRSS12"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func crssPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueCRSSIdentityKeepsTurntableAndAudioOwnershipSeparate() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["PLX-CRSS12"], automaticOnly: true))
    #expect(profile.definition?.inputs.count == 68 && profile.definition?.role == "accessory")
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
    for alias in ["Pioneer PLX-CRSS12", "Pioneer DJ PLX-CRSS12", "PLX-CRSS12 MIDI 1"] {
        #expect(ControllerFactoryProfile.matching([alias], automaticOnly: true) == profile)
    }
    for other in ["PLX-1000", "PLX-500", "RP-8000", "RP-8000 MK2", "TWELVE"] {
        #expect(ControllerFactoryProfile.matching([other]) != profile)
    }
}

@Test @MainActor func controllerCatalogueCRSSAllEightCuesUseTheirIndependentPadChannelsAndReleaseForms() throws {
    try withCRSS { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for (channel, deck) in DeckID.allCases.enumerated() {
            for slot in 0..<8 {
                let status = UInt8(0x97 + channel), note = UInt8(slot)
                let action = try #require(ControllerAction(rawValue: "hotcue\(slot + 1)A"))
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    crssPacket(
                        [status, note, 127, status, note, 127, off + UInt8(7 + channel), note, off == 0x80 ? 127 : 0],
                        to: input)
                    #expect(events == [.init(action.assigned(to: deck), deck: deck)])
                    crssPacket([status, note, 127, status, note, 0], to: input)
                    #expect(events.count == 2)
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueCRSSShiftAliasesRearmAndDeckChangesCannotStrandPhysicalShift() throws {
    try withCRSS { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for slot: UInt8 in 0..<8 {
            events.removeAll()
            crssPacket([0x97, slot, 127, 0x90, 48, 127, 0x97, slot + 8, 0], to: input)
            #expect(events.count == 1)
            crssPacket([0x97, slot, 127, slot, 0, slot + 8, 127, slot + 8, 0], to: input)
            #expect(events.count == 1)
            crssPacket([0x93, 48, 0, 0x97, slot, 127, slot, 0], to: input)
            #expect(events.count == 2)
        }
        events.removeAll()
        crssPacket([0x90, 48, 127, 0x98, 0, 127, 0, 0], to: input)
        crssPacket([0x98, 0, 127, 0, 0], to: input, source: 11)
        #expect(events == [.init(.hotcue1B, deck: .b)])
        crssPacket([0x82, 48, 127, 0x98, 0, 127, 0, 0], to: input)
        #expect(events.count == 2)
    }
}

@Test @MainActor func controllerCatalogueCRSSOtherModesAndConflictingHeldBankRowsNeverBecomeAppTransport() throws {
    try withCRSS { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for channel: UInt8 in 0..<4 {
            for number: UInt8 in [
                0, 1, 2, 3, 4, 5, 6, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 49, 50, 51, 53, 54, 55, 56, 57, 58, 59, 64,
                65, 66, 67,
            ] {
                crssPacket([0x90 + channel, number, 127, number, 0], to: input)
            }
            crssPacket([0xB0 + channel, 16, 64, 48, 0], to: input)
            for number: UInt8 in 16..<128 {
                crssPacket([0x97 + channel, number, 127, number, 0], to: input)
            }
        }
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueCRSSHiddenDecksStayInactiveAndReconnectClearsShiftAndCueEdges() throws {
    try withCRSS(decks: DeckID.primary) { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { targets.append(target) } }
        crssPacket([0x99, 0, 127, 0, 0, 0x9A, 0, 127, 0, 0, 0x97, 0, 127], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a)])
        crssPacket([0x90, 48, 127], to: input)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        crssPacket([0x97, 0, 127, 0, 0], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a), .init(.hotcue1A, deck: .a)])
    }
}
