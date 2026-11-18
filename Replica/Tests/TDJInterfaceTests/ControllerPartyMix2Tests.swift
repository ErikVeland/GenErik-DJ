import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPartyMix2(body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "party-mix-ii-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "Party Mix II", identity: .init(id: 10, device: 1, names: ["Party Mix II"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "Party Mix II", identity: .init(id: 20, device: 1, names: ["Party Mix II"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func partyMix2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCataloguePartyMix2KeepsItsOwnAliasesAndCoreControls() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Party Mix II"], automaticOnly: true))
    #expect(ControllerFactoryProfile.matching(["Numark Party Mix MK2"], automaticOnly: true) == profile)
    for name in ["Party Mix", "Party Mix Live", "Party Mix III", "Party Mix Pro"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    withPartyMix2 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        partyMix2Packet([0x90, 0, 127, 0x91, 2, 127, 0x9F, 2, 127, 3, 127], to: input)
        #expect(actions == [.playA, .syncB, .loadA, .loadB])
    }
}

@Test @MainActor func controllerCataloguePartyMix2UsesRealTouchAndReleasesBothNoteOffForms() {
    withPartyMix2 { input in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        partyMix2Packet([0x90, 6, 127, 0xB0, 6, 127], to: input)
        input.flushPendingActions()
        partyMix2Packet([0x80, 6, 0, 0x91, 6, 127, 6, 0], to: input)
        #expect(values.map(\.0) == [.jogTouchA, .jogA, .jogTouchA, .jogTouchB, .jogTouchB])
        #expect(values.map(\.1) == [1, 0.375, 0, 1, 0])
    }
}

@Test @MainActor func controllerCataloguePartyMix2BlocksOtherPadModesAndHeldPadModeDelete() {
    withPartyMix2 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        partyMix2Packet([0x94, 20, 127, 0x9F, 50, 127, 0x84, 20, 0, 0x94, 20, 127], to: input)
        #expect(actions == [.hotcue1A])
        partyMix2Packet([0x8F, 50, 0, 0x84, 20, 0, 0x94, 15, 127, 20, 127], to: input)
        #expect(actions == [.hotcue1A])
        partyMix2Packet([0x95, 23, 127], to: input)
        #expect(actions == [.hotcue1A, .hotcue4B])
        partyMix2Packet([0x94, 0, 127, 0x84, 20, 0, 0x94, 20, 127], to: input)
        #expect(actions.last == .hotcue1A)
    }
}

@Test @MainActor func controllerCataloguePartyMix2UsesBrowseSevenAndDoesNotReuseTheOldZeroAddress() {
    withPartyMix2 { input in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        partyMix2Packet([0x9F, 0, 127], to: input)
        #expect(values.isEmpty)
        partyMix2Packet([0xBF, 0, 127, 0x9F, 7, 127], to: input)
        #expect(values.map(\.0) == [.browse, .openGroup])
        #expect(values.first?.1 == 0.5 - 1.0 / 126)
    }
}

@Test @MainActor func controllerCataloguePartyMix2KeepsTempoDirectionAndClearsHeldStateOnReconnect() {
    withPartyMix2 { input in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        partyMix2Packet([0xB0, 9, 0], to: input)
        input.flushPendingActions()
        #expect(values.last?.1 == 1)
        partyMix2Packet([0xB0, 9, 127], to: input)
        input.flushPendingActions()
        #expect(values.last?.1 == 0)
        partyMix2Packet([0x9F, 50, 127, 0x94, 15, 127, 20, 127], to: input)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        partyMix2Packet([0x94, 20, 127], to: input)
        #expect(values.last?.0 == .hotcue1A)
    }
}

@Test @MainActor func controllerCataloguePartyMix2DoesNotInheritOriginalLampOrScratchLedWrites() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Party Mix II"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.startup.first == [240, 0, 1, 63, 56, 72, 247])
    #expect(!data.startup.contains { $0.first == 0xB0 || ($0.count == 3 && $0[1] == 7) })
    #expect(data.inputModes?.allSatisfy { $0.numbers == [0, 11, 14, 15] } == true)
    #expect(data.startup.count + data.shutdown.count == 15)
    #expect(
        data.shutdown == [[0x80, 0, 0], [0x80, 2, 0], [0x80, 27, 0], [0x81, 0, 0], [0x81, 2, 0], [0x81, 27, 0]])
}
