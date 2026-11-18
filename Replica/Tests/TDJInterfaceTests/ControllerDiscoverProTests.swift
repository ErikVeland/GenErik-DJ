import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDiscoverPro(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "discover-pro-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Ion Discover DJ Pro"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func discoverProPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDiscoverProKeepsItsOwnTransportAndLightValues() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["ION Discover DJ Pro"], automaticOnly: true))
    #expect(profile != ControllerFactoryProfile.matching(["Ion Discover DJ"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 34 && data.outputs.count == 10)
    #expect(data.startup.count == 30 && data.startup == data.shutdown)
    #expect(!profile.hasAutomaticSplitOutput)
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewA })
    #expect(cue.message(value: 1) == [0x90, 0x33, 100])
    #expect(cue.message(value: 0) == [0x90, 0x33, 0])
    let key = try #require(profile.feedback(destination: 20).first { $0.action == .keylockB })
    #expect(key.message(value: 1) == [0x90, 0x52, 100])
}

@Test @MainActor func controllerCatalogueDiscoverProKeepsHeldCueBendAndPFLSeparate() {
    withDiscoverPro { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        discoverProPacket(
            [0x90, 0x33, 127, 0x65, 127, 0x3B, 127, 0x43, 127, 0x44, 127, 0x80, 0x33, 127, 0x43, 0, 0x44, 0], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cuePreviewA, .cueA, .playA, .pitchBendDownA, .pitchBendUpA, .cuePreviewA, .pitchBendDownA,
                .pitchBendUpA,
            ])
        #expect(events.suffix(3).allSatisfy { $0.1 == 0 })
        events.removeAll()
        discoverProPacket([0x90, 0x3C, 127, 0x66, 127, 0x42, 127, 0x45, 127, 0x46, 127, 0x3C, 0], to: input)
        #expect(
            events.map { $0.0.action } == [.cuePreviewB, .cueB, .playB, .pitchBendDownB, .pitchBendUpB, .cuePreviewB])
        #expect(!events.contains { [.tempoUpA, .tempoDownA, .tempoUpB, .tempoDownB].contains($0.0.action) })
    }
}

@Test @MainActor func controllerCatalogueDiscoverProKeepsPitchPickupAndNormalMixerAddresses() {
    withDiscoverPro { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { events.append(($0, $1)) }
        discoverProPacket([0xB0, 13, 0], to: input)
        #expect(events.isEmpty)
        discoverProPacket([0xB0, 13, 64], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 0.5)
        discoverProPacket([0xB0, 13, 127], to: input)
        #expect(events.last?.1 == 0)
        events.removeAll()
        discoverProPacket(
            [0xB0, 8, 1, 9, 2, 16, 3, 17, 4, 18, 5, 19, 6, 20, 7, 21, 8, 10, 0, 11, 10, 12, 11, 23, 12], to: input)
        #expect(
            Set(events.map { $0.0.action }) == [
                .levelA, .levelB, .highA, .highB, .midA, .midB, .lowA, .lowB, .crossfader, .monitor, .cueMix, .master,
            ])
        #expect(events.first { $0.0.action == .crossfader }?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueDiscoverProDoesNotRunBrokenTouchScratchOrLoopHandlers() {
    withDiscoverPro { input in
        var events: [ControllerActionTarget] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, _ in events.append(target) }
        input.onJogAction = { jogs.append(($0, $1)) }
        discoverProPacket(
            [
                0x90, 0x48, 127, 0x50, 127, 0x53, 127, 0x54, 127, 0x55, 127, 0x61, 127, 0x4A, 127, 0x5A, 127, 0x63, 127,
                0x69, 127, 0xB0, 0x4D, 127, 0x4E, 127,
            ], to: input)
        #expect(events.isEmpty && jogs.isEmpty)
        discoverProPacket([0xB0, 0x19, 2, 0x18, 127], to: input)
        #expect(jogs.count == 2)
        #expect(jogs.first { $0.0.deck == .a }?.0 == .init(.wheelJogA, deck: .a, argument: 128))
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(2))
        #expect(jogs.first { $0.0.deck == .b }?.1 == .relative(-1))
        discoverProPacket([0x90, 0x4B, 127, 0x34, 127, 0x4F, 127], to: input)
        #expect(events.map(\.action) == [.loadA, .loadB, .openGroup])
        discoverProPacket([0xB0, 26, 127], to: input)
        #expect(events.last?.action == .browse)
    }
}

@Test @MainActor func controllerCatalogueDiscoverProDisconnectReleasesOwnedHoldsAndClearsOnlyReviewedLights() throws {
    let suite = "discover-pro-cleanup-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        })
    let name = "Ion Discover DJ Pro"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    let data = try #require(ControllerFactoryProfile.matching([name])?.definition)
    #expect(packets == data.startup)
    var events: [(ControllerActionTarget, Double)] = []
    input.onTargetAction = { events.append(($0, $1)) }
    discoverProPacket([0x90, 0x33, 127, 0x46, 127], to: input)
    packets.removeAll()
    input.sources = []
    input.reconcileFactoryProfiles()
    #expect(Set(events.filter { $0.1 == 0 }.map { $0.0.action }) == [.cuePreviewA, .pitchBendUpB])
    #expect(packets == data.shutdown)
}
