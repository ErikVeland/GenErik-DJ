import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPartyMix(body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "party-mix-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "Party Mix", identity: .init(id: 10, device: 1, names: ["Party Mix"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "Party Mix", identity: .init(id: 20, device: 1, names: ["Party Mix"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func partyMixPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCataloguePartyMixUsesOriginalModelAndInputLoadAddresses() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Party Mix"], automaticOnly: true))
    #expect(!profile.bindings(source: 10).contains { $0.action == .midA || $0.action == .midB })
    for name in ["Party Mix II", "Party Mix III", "Party Mix Live", "Party Mix Pro"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    withPartyMix { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        partyMixPacket([0x90, 0, 127, 0x91, 2, 127, 0x9F, 1, 127, 2, 127, 3, 127], to: input)
        #expect(
            targets == [
                .init(.playA, deck: .a), .init(.syncB, deck: .b), .init(.loadA, deck: .a), .init(.loadB, deck: .b),
            ])
    }
}

@Test @MainActor func controllerCataloguePartyMixKeepsFourCuesPerDeckAndBlocksOtherPadModes() {
    withPartyMix { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        partyMixPacket([0x94, 20, 127, 23, 127, 0x95, 23, 127], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a), .init(.hotcue4A, deck: .a), .init(.hotcue4B, deck: .b)])
        for mode: UInt8 in [11, 14, 24] {
            partyMixPacket([0x94, mode, 127, 0x84, 20, 0, 0x94, 20, 127], to: input)
        }
        #expect(targets.count == 3)
        partyMixPacket([0x85, 23, 0, 0x95, 23, 127, 0x94, 0, 127, 0x84, 20, 0, 0x94, 20, 127], to: input)
        #expect(targets.suffix(2) == [.init(.hotcue4B, deck: .b), .init(.hotcue1A, deck: .a)])
    }
}

@Test @MainActor func controllerCataloguePartyMixReconnectRestoresHotCueModeAndClearsOldEdges() {
    withPartyMix { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        partyMixPacket([0x94, 11, 127, 20, 127], to: input)
        #expect(actions.isEmpty)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        partyMixPacket([0x94, 20, 127], to: input)
        #expect(actions == [.hotcue1A])
    }
}

@Test @MainActor func controllerCataloguePartyMixSensorlessWheelsUsePitchBendWithoutTouchActions() {
    withPartyMix { input in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        partyMixPacket([0x90, 6, 127, 7, 127, 0xB0, 6, 127], to: input)
        input.flushPendingActions()
        #expect(values.map(\.0) == [.wheelJogA])
        #expect(values.first?.1 == 0.375)
        partyMixPacket([0xB1, 6, 1], to: input)
        input.flushPendingActions()
        #expect(values.last?.0 == .wheelJogB)
        #expect(values.last?.1 == 0.625)
    }
}

@Test @MainActor func controllerCataloguePartyMixUsesSevenBitTempoAndActualTwoBandMixer() {
    withPartyMix { input in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        partyMixPacket([0xB0, 9, 0, 23, 127, 24, 0, 25, 127], to: input)
        input.flushPendingActions()
        #expect(values.first { $0.0 == .tempoA }?.1 == 1)
        #expect(values.first { $0.0 == .gainA }?.1 == 1)
        #expect(values.first { $0.0 == .highA }?.1 == 0)
        #expect(values.first { $0.0 == .lowA }?.1 == 1)
        partyMixPacket([0xB0, 9, 127], to: input)
        input.flushPendingActions()
        #expect(values.last?.0 == .tempoA)
        #expect(values.last?.1 == 0)
    }
}

@Test @MainActor func controllerCataloguePartyMixKeepsPublishedSetupAndSpecialHeadphoneFeedback() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Numark Party Mix"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.startup.prefix(3) == [[0xB0, 64, 0], [0xB0, 66, 0], [0xB0, 67, 0]])
    #expect(data.startup.contains([240, 0, 1, 63, 56, 72, 247]))
    #expect(data.startup.count + data.shutdown.count == 16)
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cueA })
    #expect(cue.message(value: 1) == [0x90, 27, 127])
    #expect(cue.message(value: 0) == [0x80, 27, 1])
    #expect(!profile.feedback(destination: 20).contains { $0.action.rawValue.hasPrefix("hotcue") })
}
