import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let legacyPCDJModels = ["Numark 4TRAK", "M-Audio Xponent"]

@MainActor private func withLegacyPCDJ(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "legacy-pcdj-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = [Int32(10), 11].map { id in
        let model = id == 10 ? name : "M-Audio Xponent"
        return .init(
            id: id, reference: UInt32(id), name: model, identity: .init(id: id, device: UInt32(id), names: [model]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11) && writes == 0)
    let p = try #require(ControllerFactoryProfile.matching([name]))
    input.select(10); input.applyFactoryProfile(p)
    let second = try #require(ControllerFactoryProfile.matching(["M-Audio Xponent"]))
    input.select(11); input.applyFactoryProfile(second)
    #expect(input.bindingCount == p.bindings(source: 10).count + second.bindings(source: 11).count && writes == 0)
    try body(input)
}

@MainActor private func legacyPCDJPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: legacyPCDJModels) @MainActor func controllerCatalogueLegacyPCDJManualIdentityAndSourceOwnedCue(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(!p.selectsAutomatically && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(d.inputs.count == (name == legacyPCDJModels[0] ? 142 : 96))
    #expect(
        ControllerFactoryProfile.matching(["4TRAK FX"]) != p
            && ControllerFactoryProfile.matching(["X-Session Pro"]) != p)
    try withLegacyPCDJ(name) { input in
        let ch: UInt8 = name == legacyPCDJModels[0] ? 1 : 0; let cue: UInt8 = ch == 1 ? 16 : 35
        var values: [Double] = []
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        for off: UInt8 in [0x80 + ch, 0x90 + ch] {
            values.removeAll(); legacyPCDJPacket([0x90 + ch, cue, 127, cue, 127], input)
            legacyPCDJPacket([0x90, 35, 127], input, source: 11)
            legacyPCDJPacket([off, cue, off < 0x90 ? 127 : 0], input); #expect(values == [1])
            legacyPCDJPacket([off < 0x90 ? 0x80 : 0x90, 35, off < 0x90 ? 127 : 0], input, source: 11);
            #expect(values == [1, 0])
        }
    }
}

@Test @MainActor func controllerCatalogueLegacyPCDJ4TRAKSideAndShiftAliasesRetireOnlyOwnedCue() throws {
    try withLegacyPCDJ("Numark 4TRAK") { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA || target.action == .cuePreviewB { events.append((target.deck, value)) }
        }
        legacyPCDJPacket([0x91, 16, 127, 0x92, 16, 127], input)
        legacyPCDJPacket([0xB0, 80, 2], input); #expect(events.count == 2)
        legacyPCDJPacket([0xB0, 80, 1], input);
        #expect(events.count == 3 && events.last?.0 == .a && events.last?.1 == 0)
        legacyPCDJPacket([0xB0, 81, 0], input);
        #expect(events.count == 4 && events.last?.0 == .b && events.last?.1 == 0)
        events.removeAll(); legacyPCDJPacket([0x91, 18, 64, 16, 127, 16, 0], input); #expect(events.isEmpty)
        legacyPCDJPacket([0x83, 18, 64, 0x91, 16, 127, 0x81, 16, 127], input); #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueLegacyPCDJXponentManufacturerShiftAndOwnedTouchOverrideCopiedScript() throws {
    try withLegacyPCDJ("M-Audio Xponent") { input in
        var events: [ControllerActionTarget] = []; var jogs: [ControllerMIDIValue] = []
        input.onTargetAction = { target, _ in events.append(target) }
        input.onJogAction = { target, value in
            #expect(target.argument == 300 && target.deck == .a); jogs.append(value)
        }
        legacyPCDJPacket([0xB0, 22, 69], input); #expect(jogs.isEmpty)
        legacyPCDJPacket([0x90, 22, 127, 0xB0, 22, 69], input); #expect(jogs == [.relative(5)])
        events.removeAll(); legacyPCDJPacket([0x90, 44, 64, 35, 127, 35, 0, 18, 127, 19, 127, 0xB0, 22, 69], input)
        #expect(!events.contains { $0.action == .loadA || $0.action == .cuePreviewA } && jogs == [.relative(5)])
        legacyPCDJPacket([0x80, 44, 64, 0x90, 35, 127, 0x80, 35, 127], input)
        #expect(events.filter { $0.action == .cuePreviewA }.count == 2)
    }
}

@Test(arguments: legacyPCDJModels) @MainActor func controllerCatalogueLegacyPCDJMixerPitchAndSteadyLampPackets(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20)
    #expect(lamps.count == (name == legacyPCDJModels[0] ? 32 : 14))
    for lamp in lamps {
        let status: UInt8 = name == legacyPCDJModels[0] ? 0xB0 : 0x90
        #expect(lamp.message(value: 1) == [status + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [status + lamp.channel, lamp.number, 0])
    }
    try withLegacyPCDJ(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        if name == legacyPCDJModels[0] {
            for (n, deck): (UInt8, DeckID) in [(8, .a), (13, .b), (19, .c), (24, .d)] {
                events.removeAll(); legacyPCDJPacket([0xB0, n, 64], input);
                #expect(events.count == 1 && events.first?.0.deck == deck)
            }
            events.removeAll(); for v: UInt8 in [0, 2, 63, 64, 65, 126] { legacyPCDJPacket([0xB0, 68, v], input) };
            #expect(events.isEmpty)
            legacyPCDJPacket([0xB0, 68, 1], input); legacyPCDJPacket([0xB0, 68, 127], input)
            #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        } else {
            legacyPCDJPacket([0xE0, 0, 64], input); legacyPCDJPacket([0xE0, 127, 127], input);
            #expect(events.map(\.1) == [0.5, 0])
            events.removeAll(); legacyPCDJPacket([0xB2, 13, 64], input);
            #expect(events.count == 1 && events.first?.0.action == .cueMix)
        }
    }
}
