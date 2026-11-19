import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalBeatMix(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "original-beatmix-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "Reloop BeatMix",
            identity: .init(id: id, device: UInt32(id), names: ["Reloop BeatMix"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func originalBeatMixPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalBeatMixStartsAndKeepsTransportWiresSeparate() throws {
    try withOriginalBeatMix { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in DeckID.primary.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [
                (47, .playA), (44, .syncA), (35, .cueA), (50, .loadA), (channel == 0 ? 34 : 33, .loopA),
                (41, .hotcue1A), (42, .hotcue2A), (43, .hotcue3A),
            ] {
                events.removeAll()
                originalBeatMixPacket([0x90 + UInt8(channel), number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for number: UInt8 in [46, 38, 39, 63] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    originalBeatMixPacket(
                        [
                            0x90 + UInt8(channel), number, 127, number, 127, off + UInt8(channel), number,
                            off == 0x80 ? 127 : 0,
                        ], input)
                    #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalBeatMixKeepsSideShiftAndSharedSoundOwnership() throws {
    try withOriginalBeatMix { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        originalBeatMixPacket([0x90, 46, 127, 0x91, 46, 127], input)
        originalBeatMixPacket([0x90, 46, 127], input, source: 11)
        originalBeatMixPacket([0x90, 36, 127], input)
        #expect(events.count == 2)
        originalBeatMixPacket([0x80, 46, 127], input, source: 11)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        originalBeatMixPacket([0x90, 46, 127, 0x80, 36, 127], input)
        #expect(events.last?.1 == 1)
        originalBeatMixPacket([0x90, 40, 127], input)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        events.removeAll()
        originalBeatMixPacket([0x90, 41, 127, 41, 0, 0x91, 41, 127, 41, 0, 0xB4, 24, 65, 0x94, 64, 127, 64, 0], input)
        #expect(events.map(\.0.action) == [.hotcue1B, .openGroup])
        events.removeAll()
        input.currentTargetValue = { _ in 0.5 }
        originalBeatMixPacket([0xB0, 55, 64], input)
        originalBeatMixPacket([0xB4, 83, 64], input)
        #expect(events.map(\.0.action) == [.levelA, .crossfader])
        originalBeatMixPacket([0x80, 40, 127], input)
    }
}

@Test @MainActor func controllerCatalogueOriginalBeatMixUsesQualifiedTSIEncoderAndMixerFacts() throws {
    try withOriginalBeatMix { input in
        var jogs: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { target, value in if case .relative(let count) = value { jogs.append((target, count)) } }
        for (channel, number, deck): (UInt8, UInt8, DeckID) in [(0, 36, .a), (1, 42, .b)] {
            jogs.removeAll()
            for value: UInt8 in [65, 63, 127, 0, 64] { originalBeatMixPacket([0xB0 + channel, number, value], input) }
            #expect(jogs.map(\.1) == [1, -1, 63, -64] && jogs.allSatisfy { $0.0.deck == deck })
        }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        input.currentTargetValue = { _ in 0.5 }
        originalBeatMixPacket([0xB1, 69, 64], input)
        #expect(events.last?.0.action == .lowB)
        events.removeAll()
        originalBeatMixPacket([0xB0, 69, 127, 0xB3, 81, 127, 82, 127, 83, 127], input)
        #expect(events.isEmpty)
        originalBeatMixPacket([0xB4, 81, 64], input)
        originalBeatMixPacket([0xB4, 82, 64], input)
        originalBeatMixPacket([0xB4, 83, 64], input)
        #expect(events.map(\.0.action) == [.monitor, .cueMix, .crossfader])
        events.removeAll()
        originalBeatMixPacket([0xB0, 54, 64], input)
        originalBeatMixPacket([0xB0, 118, 127], input)
        originalBeatMixPacket([0xB0, 54, 127], input)
        #expect(events.count == 2 && events.allSatisfy { $0.0.action == .tempoA } && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueOriginalBeatMixRejectsSiblingNamesAndUnusedTemplateStreams() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Reloop BeatMix"], automaticOnly: true))
    let definition = try #require(profile.definition)
    #expect(definition.inputs.count == 50 && definition.outputs.isEmpty)
    #expect(definition.startup.isEmpty && definition.shutdown.isEmpty && definition.audioOutput == nil)
    for name in ["Beatmix 2", "Beatmix 4", "Beatmix 2 MK2", "Beatmix clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    try withOriginalBeatMix { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        for (channel, normal, search): (UInt8, UInt8, UInt8) in [(0, 32, 40), (1, 34, 38)] {
            originalBeatMixPacket([0xB0 + channel, normal, 65, search, 65], input)
        }
        #expect(actions.isEmpty)
    }
}
