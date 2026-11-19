import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPartyLive(
    sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true }, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "party-live-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: sender)
    let name = "Party Mix Live"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func partyLivePacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePartyMixLiveKeepsItsOwnIdentityAndReviewedLamps() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Party Mix Live"], automaticOnly: true))
    for name in ["Party Mix", "Party Mix II", "Party Mix MK2", "Party Mix III", "Party Mix Pro"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 48 && data.outputs.count == 6)
    #expect(data.inputModes?.count == 2 && !profile.hasAutomaticSplitOutput)
    #expect(!data.startup.contains { $0.first == 0xF0 || $0[1] == 50 })
    #expect(!data.inputs.contains { $0.kind == .pitch })
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewA })
    #expect(cue.message(value: 0) == [0x90, 1, 1])
    let pfl = try #require(profile.feedback(destination: 20).first { $0.action == .cueB })
    #expect(pfl.message(value: 0) == [0x81, 27, 0])
}

@Test @MainActor func controllerCataloguePartyMixLiveSelectsCoreWithoutShiftOrPadSideEffects() {
    withPartyLive { input in
        #expect(input.isInputActive(10))
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        partyLivePacket([0x90, 0, 127, 1, 127, 1, 0, 0x91, 2, 127, 0x9F, 2, 127, 3, 127, 7, 127], to: input)
        #expect(events.map(\.0) == [.playA, .cuePreviewA, .cuePreviewA, .syncB, .loadA, .loadB, .openGroup])
        events.removeAll()
        partyLivePacket([0x9F, 0, 127, 50, 127, 0x94, 11, 127, 15, 127, 20, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCataloguePartyMixLiveUsesRaw64PositiveJogAndUninvertedPitch() {
    withPartyLive { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        partyLivePacket([0xB0, 9, 0], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 0)
        partyLivePacket([0xB0, 9, 127], to: input)
        #expect(events.last?.1 == 1)
        partyLivePacket([0x90, 6, 127, 0xB0, 6, 64], to: input)
        #expect(events.last?.0 == .jogA && (events.last?.1 ?? 0) > 0.5)
        partyLivePacket([0xB0, 6, 127], to: input)
        #expect(events.last?.0 == .jogA && (events.last?.1 ?? 1) < 0.5)
        partyLivePacket([0x80, 6, 127, 0x91, 6, 127, 6, 0], to: input)
        #expect(events.suffix(3).map(\.0) == [.jogTouchA, .jogTouchB, .jogTouchB])
        #expect(events.suffix(3).map(\.1) == [0, 1, 0])
        events.removeAll()
        partyLivePacket([0xBF, 0, 1], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        partyLivePacket([0xBF, 0, 127], to: input)
        #expect(events.last?.1 == 0.5 - 1.0 / 126)
    }
}

@Test @MainActor func controllerCataloguePartyMixLiveKeepsFilterAndTwoBandMixerAddresses() {
    withPartyLive { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        partyLivePacket([0xB0, 23, 127, 24, 127, 25, 127, 26, 127, 28, 127], to: input)
        #expect(Set(events) == Set([.gainA, .highA, .lowA, .filterKnobA, .levelA]))
        events.removeAll()
        partyLivePacket([0xBF, 8, 127, 10, 127, 12, 127, 13, 127], to: input)
        #expect(Set(events) == Set([.crossfader, .master, .monitor, .cueMix]))
    }
}

@Test @MainActor func controllerCataloguePartyMixLivePadModesGateDecksWithoutSendingUnqualifiedLights() {
    var packets: [[UInt8]] = []
    withPartyLive(sender: { bytes, _ in
        packets.append(bytes); return true
    }) { input in
        packets.removeAll()
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        partyLivePacket([0x94, 20, 127, 0x84, 20, 0, 0x94, 11, 127, 20, 127, 0x84, 20, 0], to: input)
        #expect(events == [.init(.hotcue1A, deck: .a)])
        partyLivePacket([0x95, 23, 127, 0x85, 23, 0], to: input)
        #expect(events.last == .init(.hotcue4B, deck: .b))
        partyLivePacket([0x94, 14, 127, 20, 127, 0x84, 20, 0, 0x94, 15, 127, 20, 127], to: input)
        #expect(events.map(\.action) == [.hotcue1A, .hotcue4B, .toggleFixedLoopA])
        #expect(packets.isEmpty)
    }
}

@Test @MainActor func controllerCataloguePartyMixLiveModeStateSurvivesDiscoveryAndResetsOnReconnect() {
    withPartyLive { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        partyLivePacket([0x94, 14, 127, 20, 127, 0x84, 20, 0], to: input)
        input.reconcileFactoryProfiles()
        partyLivePacket([0x94, 21, 127, 0x84, 21, 0], to: input)
        #expect(events.map(\.action) == [.toggleFixedLoopA, .toggleFixedLoopA])
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        partyLivePacket([0x94, 20, 127], to: input)
        #expect(events.last == .init(.hotcue1A, deck: .a))
    }
}
