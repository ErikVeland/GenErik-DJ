import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withNDX500(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "ndx500-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Numark NDX500", identity: .init(id: 10, device: 1, names: ["Numark NDX500"])),
        .init(
            id: 20, reference: 200, name: "Numark NDX500", identity: .init(id: 20, device: 2, names: ["Numark NDX500"])),
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(20))
    try body(input)
}

@MainActor private func ndxPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueNDX500KeepsSeparatePlayerIdentityAndEmitsNoUnknownChannelOutput() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["NDX500"], automaticOnly: true))
    #expect(profile.isPlayer && !profile.hasAutomaticSplitOutput)
    #expect(profile != ControllerFactoryProfile.matching(["NDX900"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(Set(data.inputs.map(\.channel)) == [0, 1, 2, 3])
    #expect(!data.inputs.contains { [.syncA, .syncB].contains($0.action) })
}

@Test @MainActor func controllerCatalogueNDX500AssignsIndependentPlayersAndKeepsDocumentedWireChannels() {
    withNDX500 { input in
        #expect(input.playerDeck(source: 10) == .a && input.playerDeck(source: 20) == .b)
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        ndxPacket([0x90, 6, 127, 3, 127], to: input)
        ndxPacket([0x93, 6, 127, 3, 127], to: input, source: 20)
        #expect(events.map(\.action) == [.playA, .loadA, .playB, .loadB])
        ndxPacket([0x94, 6, 127, 3, 127], to: input)
        #expect(events.count == 4)
    }
}

@Test @MainActor func controllerCatalogueNDX500HeldCueBendAndContactReleaseAcrossHardwareChannels() {
    withNDX500 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        ndxPacket([0x90, 5, 127, 24, 127, 25, 127, 0x83, 5, 127, 24, 127, 25, 127], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cuePreviewA, .pitchBendUpA, .jogTouchA, .cuePreviewA, .pitchBendUpA, .jogTouchA,
            ])
        #expect(events.map(\.1) == [1, 1, 1, 0, 0, 0])
        events.removeAll()
        ndxPacket([0x92, 5, 127, 23, 127, 5, 0, 23, 0], to: input, source: 20)
        #expect(events.map { $0.0.action } == [.cuePreviewB, .pitchBendDownB, .cuePreviewB, .pitchBendDownB])
        #expect(events.map(\.1) == [1, 1, 0, 0])
    }
}

@Test @MainActor func controllerCatalogueNDX500JogsBrowserPitchAndThreeCuesKeepSourceFacts() {
    withNDX500 { input in
        var events: [(ControllerActionTarget, Double)] = []
        var jogs: [ControllerMIDIValue] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.onJogAction = { _, value in jogs.append(value) }
        ndxPacket([0xB1, 34, 62], to: input)
        ndxPacket([0xB1, 34, 63], to: input)
        ndxPacket([0xB1, 34, 64], to: input)
        #expect(jogs == [.relative(1), .relative(-1)])
        ndxPacket([0xB1, 33, 1], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        ndxPacket([0xB1, 33, 0], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        ndxPacket([0xE1, 0, 0], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 1)
        ndxPacket([0xE1, 127, 127], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 0)
        events.removeAll()
        ndxPacket([0x91, 11, 127, 12, 127, 13, 127, 7, 127, 8, 127, 9, 127], to: input)
        #expect(events.map { $0.0.action } == [.hotcue1A, .hotcue2A, .hotcue3A, .loopInA, .loopOutA, .reloopA])
    }
}
