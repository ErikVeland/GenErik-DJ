import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withInpulse300MK2(_ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void) rethrows {
    let suite = "inpulse300mk2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes)
            return true
        }, deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "DJControl Inpulse 300 MK2",
            identity: .init(id: 10, device: 1, names: ["DJControl Inpulse 300 MK2"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "DJControl Inpulse 300 MK2",
            identity: .init(id: 20, device: 1, names: ["DJControl Inpulse 300 MK2"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func inpulseMK2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueInpulse300MK2KeepsItsOwnIdentityAndTwoDeckCore() throws {
    try withInpulse300MK2 { input, packets in
        #expect(input.isInputActive(10))
        #expect(packets == [[0x94, 1, 127], [0x95, 1, 127], [0x90, 4, 5], [0xB0, 127, 127]])
        let profile = try #require(
            ControllerFactoryProfile.matching(["DJControl Inpulse 300 MK2"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == 47 && data.outputs.count == 10)
        #expect(data.inputs.allSatisfy { $0.targetDeck == nil || $0.targetDeck == .a || $0.targetDeck == .b })
        #expect(ControllerFactoryProfile.matching(["DJControl Inpulse 300"]) != profile)
        #expect(ControllerFactoryProfile.matching(["DJControl Inpulse 300 MK3"]) == nil)
    }
}

@Test @MainActor func controllerCatalogueInpulse300MK2RoutesNormalControlsAndFourTimesShiftedJogs() {
    withInpulse300MK2 { input, _ in
        var events: [ControllerActionTarget] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, _ in events.append(target) }
        input.onJogAction = { target, value in jogs.append((target, value)) }
        inpulseMK2Packet([0x91, 7, 127, 13, 127, 0x92, 12, 127, 0x94, 2, 127], to: input)
        #expect(
            events == [
                .init(.playA, deck: .a), .init(.loadA, deck: .a), .init(.cueB, deck: .b), .init(.keylockA, deck: .a),
            ])
        inpulseMK2Packet([0xB1, 10, 1], to: input)
        inpulseMK2Packet([0xB4, 10, 127], to: input)
        inpulseMK2Packet([0xB2, 9, 1], to: input)
        #expect(
            jogs.map(\.0) == [
                .init(.jogA, deck: .a, argument: 248), .init(.jogA, deck: .a, argument: 62),
                .init(.wheelJogB, deck: .b, argument: 248),
            ])
        #expect(jogs.map(\.1) == [.relative(1), .relative(-1), .relative(1)])
    }
}

@Test @MainActor func controllerCatalogueInpulse300MK2RejectsConflictingPadsAndCustomSoftwareBanks() {
    withInpulse300MK2 { input, _ in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        inpulseMK2Packet(
            [
                0x90, 3, 127, 0x96, 0, 127, 7, 127, 0x97, 0, 127, 0x94, 13, 127,
                0x95, 13, 127, 0x91, 9, 127, 10, 127,
            ], to: input)
        #expect(events.isEmpty)
        inpulseMK2Packet([0x91, 6, 127, 0x94, 6, 0, 0x91, 6, 127, 0x81, 6, 0], to: input)
        #expect(events.map(\.action) == [.cuePreviewA, .cuePreviewA, .cuePreviewA, .cuePreviewA])
    }
}
