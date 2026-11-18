import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRMP4(_ body: (ControllerMIDIConnection) -> Void) {
    let suite = "rmp4-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "RMP-4", identity: .init(id: 10, device: 1, names: ["RMP-4"])),
        .init(id: 20, reference: 200, name: "RMP-4", identity: .init(id: 20, device: 2, names: ["RMP-4"])),
    ]
    input.reconcileFactoryProfiles()
    body(input)
}

@MainActor private func rmp4Packet(_ bytes: [UInt8], source: Int32 = 10, to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRMP4KeepsItsPlayerIdentityWithoutGuessedOutput() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["RMP-4"], automaticOnly: true))
    #expect(profile.rawValue == "Reloop RMP-4" && profile.isPlayer && !profile.hasAutomaticSplitOutput)
    for name in ["RMP-3", "RMP3", "RMP-2.5 Alpha", "RMP-2"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 188)
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
}

@Test @MainActor func controllerCatalogueRMP4AssignsTwoPlayersAcrossTheirWireChannels() {
    withRMP4 { input in
        #expect(input.playerDeck(source: 10) == .a && input.playerDeck(source: 20) == .b)
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        rmp4Packet([0x90, 76, 127, 90, 127], to: input)
        rmp4Packet([0x93, 76, 127, 90, 127], source: 20, to: input)
        #expect(events.map(\.action) == [.playA, .loadA, .playB, .loadB])
        rmp4Packet([0x94, 76, 127, 0x90, 124, 127, 125, 127, 126, 127, 127, 127, 8, 127, 16, 127, 24, 127], to: input)
        rmp4Packet([0x90, 76, 127], source: 99, to: input)
        #expect(events.count == 4)
    }
}

@Test @MainActor func controllerCatalogueRMP4ShiftReleasesHeldCueContactAndBendsWithoutNewPresses() {
    withRMP4 { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        rmp4Packet([0x90, 75, 127, 91, 127, 88, 127, 89, 127, 0x93, 107, 127, 123, 127, 120, 127, 121, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .jogTouchA, .pitchBendDownA, .pitchBendUpA])
        rmp4Packet([0x83, 107, 127, 123, 127, 120, 127, 121, 127], to: input)
        #expect(events.suffix(4).map(\.0) == [.cuePreviewA, .jogTouchA, .pitchBendDownA, .pitchBendUpA])
        #expect(events.suffix(4).map(\.1) == [0, 0, 0, 0])
        rmp4Packet([0x90, 75, 127, 75, 0], to: input)
        #expect(events.suffix(2).map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueRMP4JogsBrowsePitchAndCueReleaseKeepSourceAddresses() {
    withRMP4 { input in
        var events: [(ControllerAction, Double)] = []
        var jogs: [ControllerMIDIValue] = []
        input.onAction = { events.append(($0, $1)) }
        input.onJogAction = { _, value in jogs.append(value) }
        rmp4Packet([0xB2, 1, 63], to: input)
        rmp4Packet([0xB2, 1, 64], to: input)
        rmp4Packet([0xB2, 1, 65], to: input)
        #expect(jogs == [.relative(-1), .relative(1)])
        rmp4Packet([0xB2, 3, 65], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        rmp4Packet([0xB2, 4, 63], to: input)
        #expect(events.last?.1 == 0.5 - 1.0 / 126)
        rmp4Packet([0xE2, 0, 0], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 0)
        rmp4Packet([0xE2, 127, 127], to: input)
        #expect(events.last?.1 == 1)
        events.removeAll()
        rmp4Packet([0x92, 0, 127, 0x82, 32, 0, 0x92, 0, 127, 0x82, 0, 0], to: input)
        #expect(events.map(\.0) == [.hotcue1A, .hotcue1A])
    }
}
